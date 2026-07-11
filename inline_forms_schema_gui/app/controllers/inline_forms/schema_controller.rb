# -*- encoding : utf-8 -*-

module InlineForms
  # GUI to add a field to a model through the browser, building on the
  # schema-staging services in inline_forms. Two ways to act on an intent:
  #
  #  * DIRECT APPLY (dev only, the phase-0 flow): `create` runs
  #    inline_forms_addto in-process (model edit + migration file) but NOT
  #    db:migrate; the pending-migration gate covers the window.
  #  * BATCH DRAFTING (the pipeline flow): `draft` persists the intent into
  #    the current draft SchemaBatch (the "cart"); `submit_batch` freezes it
  #    for the automated pull -> CI -> deploy loop. Nothing is generated in
  #    the request cycle.
  #
  # Production posture: direct apply is NEVER available in production
  # (production never writes code). Drafting is also non-production unless
  # the app opts in (InlineFormsSchemaGui.production_drafting = true — the
  # SaaS tenant case). The machine endpoints (export/batch_status) are
  # token-authenticated and environment-independent, for the CI side.
  class SchemaController < InlineFormsApplicationController
    HEADER = InlineFormsSchemaGui::IntentValidator::HEADER

    layout "inline_forms_schema"

    skip_before_action :verify_authenticity_token, only: :batch_status, raise: false

    before_action :require_non_production, only: :create
    before_action :require_drafting_allowed, except: [ :create, :export, :batch_status ]
    before_action :authenticate_pipeline_token!, only: [ :export, :batch_status ]
    before_action :load_form_options, only: [ :new, :preview, :create, :draft ]
    before_action :require_batch_tables, only: [ :index, :draft, :remove_draft, :submit_batch ]

    # Injectable so tests record instead of mutating the working tree.
    cattr_accessor :generator_executor
    cattr_accessor :label_writer

    # The cart + batch history.
    def index
      @draft_batch = InlineForms::SchemaBatch.with_status(:draft).order(:id).first
      @batches = InlineForms::SchemaBatch.where.not(status: "draft").order(id: :desc).limit(25)
    end

    def new
      @intent_params = blank_intent_params
    end

    def preview
      @intent_params = intent_params
      @error = InlineFormsSchemaGui::IntentValidator.error_for(@intent_params)
      return render(:new) if @error

      @intent    = build_intent(@intent_params)
      @is_header = @intent.form_element == :header
      if @is_header
        @attribute_list = InlineForms::SchemaPreview.attribute_list_for(@intent.model_class, @intent)
      else
        @preview, @attribute_list = InlineForms::SchemaPreview.build(@intent)
      end
      @batching_available = batch_tables_present?
    end

    # DIRECT APPLY (dev only): codegen into this checkout's tree.
    def create
      @intent_params = intent_params
      @error = InlineFormsSchemaGui::IntentValidator.error_for(@intent_params)
      return render(:new) if @error

      @intent    = build_intent(@intent_params)
      @is_header = @intent.form_element == :header
      begin
        @migration_path = InlineForms::SchemaApply.new(@intent).generate!(
          destination_root: Rails.root,
          executor: generator_executor || InlineForms::SchemaApply::DEFAULT_GENERATE_EXECUTOR
        )
        @migration_basename = @migration_path && File.basename(@migration_path)
        write_label!
      rescue StandardError => e
        @error = "Generator failed: #{e.message}"
        render(:new)
      end
    end

    # BATCH DRAFTING: persist the intent into the current draft batch.
    def draft
      @intent_params = intent_params
      @error = InlineFormsSchemaGui::IntentValidator.error_for(@intent_params)
      return render(:new) if @error

      batch = InlineForms::SchemaBatch.current_draft
      batch.intents.create!(
        target_model: @intent_params[:model_name],
        attr_name:    @intent_params[:attribute],
        form_element: @intent_params[:form_element],
        after_attr:   @intent_params[:after].presence,
        label:        @intent_params[:label].presence,
        locale:       @intent_params[:locale].presence
      )
      redirect_to inline_forms_schema_index_path
    end

    def remove_draft
      intent = InlineForms::SchemaIntentRecord.find(params[:id])
      if intent.batch&.draft?
        intent.destroy
        redirect_to inline_forms_schema_index_path
      else
        redirect_to inline_forms_schema_index_path, alert: "Batch is frozen."
      end
    end

    def submit_batch
      batch = InlineForms::SchemaBatch.current_draft
      window = params[:window_at].presence && Time.zone.parse(params[:window_at])
      batch.submit!(requested_by: requesting_identity, window_at: window)
      redirect_to inline_forms_schema_index_path
    rescue ArgumentError => e
      redirect_to inline_forms_schema_index_path, alert: e.message
    end

    # MACHINE ENDPOINT (token): the frozen batch as JSON for the CI side.
    def export
      batch = InlineForms::SchemaBatch.find(params[:id])
      return render(json: { error: "batch is still a draft" }, status: :conflict) if batch.draft?

      render json: InlineFormsSchemaGui::BatchExport.payload(batch)
    end

    # MACHINE ENDPOINT (token): CI reports progress back.
    # Params: status (processing|ready|applied|failed), git_sha, error.
    def batch_status
      batch = InlineForms::SchemaBatch.find(params[:id])
      batch.transition!(params[:status].to_s, git_sha: params[:git_sha].presence, error: params[:error].presence)
      render json: { id: batch.id, status: batch.status }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def require_non_production
      head :not_found if Rails.env.production?
    end

    def require_drafting_allowed
      return unless Rails.env.production?

      head :not_found unless InlineFormsSchemaGui.production_drafting
    end

    # 404 when unconfigured (don't advertise the endpoint), 401 on mismatch.
    def authenticate_pipeline_token!
      configured = InlineFormsSchemaGui.export_token
      return head(:not_found) if configured.blank?

      provided = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1] || params[:token].to_s
      unless ActiveSupport::SecurityUtils.secure_compare(configured, provided.to_s)
        head :unauthorized
      end
    end

    def batch_tables_present?
      InlineForms::SchemaBatch.table_exists? && InlineForms::SchemaIntentRecord.table_exists?
    rescue StandardError
      false
    end

    def require_batch_tables
      return if batch_tables_present?

      render plain: "Schema-GUI batch tables missing. Run: bin/rails g inline_forms_schema_gui:install && bin/rails db:migrate",
             status: :service_unavailable
    end

    def requesting_identity
      return nil unless respond_to?(:current_user, true)

      current_user&.email
    rescue StandardError
      nil
    end

    def load_form_options
      @form_elements = InlineForms::SchemaPreview.supported_form_elements
      @models        = InlineFormsSchemaGui::IntentValidator.candidate_models
      @locales       = I18n.available_locales.map(&:to_s)
      @default_locale = I18n.default_locale.to_s
    end

    def blank_intent_params
      { model_name: "", attribute: "", form_element: @form_elements.first.to_s,
        after: "", label: "", locale: @default_locale }
    end

    def intent_params
      {
        model_name:   params[:model_name].to_s.strip,
        attribute:    params[:attribute].to_s.strip,
        form_element: params[:form_element].to_s.strip,
        after:        params[:after].to_s.strip,
        label:        params[:label].to_s.strip,
        locale:       params[:locale].to_s.strip.presence || @default_locale
      }
    end

    def build_intent(p)
      InlineForms::SchemaIntent.new(
        model_name:   p[:model_name],
        attribute:    p[:attribute],
        form_element: p[:form_element],
        after:        p[:after].presence
      )
    end

    def write_label!
      return if @intent_params[:label].blank?

      writer = label_writer || InlineForms::SchemaLabel.method(:write)
      @label_path = writer.call(
        destination_root: Rails.root,
        model_class: @intent.model_class,
        attribute: @intent.attribute,
        label: @intent_params[:label],
        locale: @intent_params[:locale]
      )
      @label_basename = @label_path && File.basename(@label_path.to_s)
    end
  end
end
