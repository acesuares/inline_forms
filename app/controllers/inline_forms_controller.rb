# -*- encoding : utf-8 -*-
# == Generic controller for the inline_forms plugin.
# === Usage
# If you have an Example class, make an ExampleController
# that is a subclass of InlineFormsController
#  class ExampleController < InlineFormsController
#  end
# That's it! It'll work. But please read about the InlineForms::InlineFormsGenerator first!
#
# You can override the methods in your ExampleController
#  def index
#    @objects=@Klass.all
#  end
#
#
# @objects holds the objects (in this case Examples)
# and @Klass will be set to Example by the getKlass before filter.
#
# === How it works
# The getKlass before_action extracts the class and puts it in @Klass
#
# @Klass is used in the InlineFormsHelper
#
class InlineFormsController < ApplicationController
  include InlineForms::FormElements::HelperIncludes
  include CancanConcern
  include VersionsConcern

  before_action :getKlass

  load_and_authorize_resource :except => :revert, :no_params => true if cancan_enabled?
  # :index shows a list of all objects from class @Klass, using will_paginate,
  # including a link to 'new', that allows you to create a new record.
  def index
    @update_span = params[:update]
    @parent_class = params[:parent_class]
    @parent_id = params[:parent_id]
    @ul_needed = params[:ul_needed]
    # Nested associated lists scope to the parent FK. Top-level lists may
    # apply the model's `inline_forms_search` scope when ?search= is passed.
    fk_conditions = nil
    if @parent_class.present? && @Klass.reflect_on_association(@parent_class.underscore.to_sym)
      foreign_key = @Klass.reflect_on_association(@parent_class.underscore.to_sym).options[:foreign_key] || @parent_class.foreign_key
      fk_conditions = [ "#{foreign_key} = ?", @parent_id ]
    end
    # CanCan's load_and_authorize_resource sets @apartments (etc.); keep @objects in sync.
    collection_ivar = :"@#{controller_name}"
    if instance_variable_defined?(collection_ivar)
      loaded = instance_variable_get(collection_ivar)
      @objects = loaded unless loaded.nil?
    end
    @objects ||= @Klass.accessible_by(current_ability) if cancan_enabled?
    @objects ||= @Klass.all
    @objects = @objects.merge(@Klass.inline_forms_list) if @Klass.respond_to?(:inline_forms_list)
    if fk_conditions.nil? && params[:search].present? && @Klass.respond_to?(:inline_forms_search)
      @objects = @objects.merge(@Klass.inline_forms_search(params[:search]))
    end
    @objects = @objects.where(fk_conditions) if fk_conditions
    @objects = @objects.paginate(:page => params[:page])
    respond_to do |format|
      # `not_accessible_through_html?` is about preventing direct top-level
      # HTML CRUD on this resource (e.g. /photos when only Apartment is the
      # public surface). The *nested* HTML render -- where `parent_class`
      # was supplied and the response is destined for a parent page's
      # `<turbo-frame>` -- is gated by the parent already (and by cancan
      # above), so we still serve it.
      #
      # Layout choice (was `layout: false` in 7.2.0):
      # - Turbo frame requests (`Turbo-Frame` header) use
      #   `turbo_rails/frame` — minimal `<html><body>` wrapper so the
      #   response parses as a document (turbo-rails default; see
      #   Turbo::Frames::FrameRequest). A bare fragment from `layout: false`
      #   is supposed to work but has been brittle for some clients; the
      #   gem layout is the supported path.
      # - Full-page visits (user opens /photos?... in the tab, or any
      #   navigation without the header) use `inline_forms` so the page is
      #   styled and bootstrapped instead of a naked `<turbo-frame>`.
      #   Turbo still extracts the matching frame when the request *is*
      #   a frame visit, regardless of outer layout (turbo-rails README).
      if @Klass.not_accessible_through_html?
        format.html do
          if @parent_class.present?
            render_nested_associated_list_html
          end
        end
      else
        format.html do
          if @parent_class.present?
            render_nested_associated_list_html
          elsif turbo_frame_request? && list_frame_id?(params[:update])
            @ul_needed = true
            render "inline_forms/_list", layout: "turbo_rails/frame"
          else
            render "inline_forms/_list", layout: "inline_forms"
          end
        end
      end
    end
  end

  # :new prepares a new object, updates the list of objects and replaces it with
  # an empty form. After pressing OK or Cancel, the list of objects is retrieved
  # in the same way as :index
  def new
    @object ||= @Klass.new
    @update_span = params[:update]
    @parent_class = params[:parent_class]
    begin
      @parent_id = params[:parent_id]
      foreign_key = @Klass.reflect_on_association(@parent_class.underscore.to_sym).options[:foreign_key] || @parent_class.foreign_key
      @object[foreign_key] = @parent_id
    end unless @parent_class.nil? || @Klass.reflect_on_association(@parent_class.underscore.to_sym).nil?

    @object.inline_forms_attribute_list = @inline_forms_attribute_list if @inline_forms_attribute_list
    respond_to do |format|
      format.html { render_turbo_new } if html_list_flow_allowed?
    end
  end

  # :edit presents a form to edit one specific attribute from an object
  def edit
    @object = referenced_object
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    respond_to do |format|
      format.html { render_turbo_field(:field_edit) }
    end
  end

  # :create creates the object made with :new.
  # It then presents the list of objects.
  def create
    @object ||= @Klass.new
    @update_span = params[:update]
    attributes = @inline_forms_attribute_list || @object.inline_forms_attribute_list
    attributes.each do | attribute, form_element |
      InlineForms.assert_plain_text_column!(object: @object, attribute: attribute, form_element: form_element)
      send("#{form_element.to_s}_update", @object, attribute) unless form_element == :associated || (cancan_enabled? && cannot?(:read, @object, attribute))
    end
    @parent_class = params[:parent_class]
    @parent_id = params[:parent_id]
    # See #index for the order/search/parent-fk decomposition.
    fk_conditions = nil
    if @parent_class.present? && @Klass.reflect_on_association(@parent_class.underscore.to_sym)
      foreign_key = @Klass.reflect_on_association(@parent_class.underscore.to_sym).options[:foreign_key] || @parent_class.foreign_key
      fk_conditions = [ "#{foreign_key} = ?", @parent_id ]
      @object[foreign_key] = @parent_id
    end

    if @object.save
      flash.now[:success] = t('success', :message => @object.class.model_name.human)
      @objects = cancan_enabled? ? @Klass.accessible_by(current_ability) : @Klass.all
      @objects = @objects.merge(@Klass.inline_forms_list) if @Klass.respond_to?(:inline_forms_list)
      if fk_conditions.nil? && params[:search].present? && @Klass.respond_to?(:inline_forms_search)
        @objects = @objects.merge(@Klass.inline_forms_search(params[:search]))
      end
      @objects = @objects.where(fk_conditions) if fk_conditions
      @objects = @objects.paginate(:page => params[:page])
      @object = nil
      respond_to do |format|
        format.html { render_list_frame_after_save } if html_list_flow_allowed?
      end
    else
      flash.now[:header] = ["Kan #{@object.class.to_s.underscore} niet aanmaken."]
      flash.now[:error] = @object.errors.to_a
      respond_to do |format|
        @object.inline_forms_attribute_list = attributes
        format.html { render_turbo_new } if html_list_flow_allowed?
      end
    end
  end

  # :update updates a specific attribute from an object.
  def update
    @object = referenced_object
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    InlineForms.assert_plain_text_column!(object: @object, attribute: @attribute, form_element: @form_element)
    send("#{@form_element.to_s}_update", @object, @attribute)
    # Branch on the actual save result. Previously the return value of
    # `@object.save` was ignored and `field_show` was rendered
    # unconditionally from the in-memory `@object`. When a save failed
    # validation (e.g. money-rails rejecting an unparseable amount, or any
    # `validates` failure) the user saw a "show" of the unsaved in-memory
    # value -- a fake success -- while the DB row kept its old value. A
    # subsequent edit then re-read the old value, surprising the user.
    #
    # On failure we keep the user in the edit field with their rejected
    # input visible and surface the validation errors (mirrors `create`).
    if @object.save
      respond_to do |format|
        format.html { render_turbo_field(:field_show, turbo_field_show: true) }
      end
    else
      flash.now[:error] = @object.errors.to_a
      respond_to do |format|
        format.html { render_turbo_field(:field_edit) }
      end
    end
  end

  # :show shows one attribute (attribute) from a record (object).
  # It includes the link to 'edit'
  def show
    @object = referenced_object
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    close = params[:close] || false
    if @form_element == "associated"
      @sub_id = params[:sub_id]
      if @sub_id.to_i > 0
        @associated_record_id = @object.send(@attribute.to_s.singularize + "_ids").index(@sub_id.to_i)
        @associated_record = @object.send(@attribute)[@associated_record_id]
      end
    end
    if @form_element == "has_one"
      @associated_record = @object.send(@attribute)
      @associated_record_id = @associated_record.id
    end
    @update_span = params[:update]
    if @attribute.nil?
      respond_to do |format|
        @attributes = @object.inline_forms_attribute_list
        if close
          format.html { render_row_turbo(:close) } if row_html_turbo_allowed?
        else
          format.html { render_row_turbo(:show) } if row_html_turbo_allowed?
        end
      end
    else
      respond_to do |format|
        format.html { render_turbo_field(:field_show, turbo_field_show: true) }
      end
    end
  end

  # :soft_delete
  def soft_delete
    @update_span = params[:update]
    @object = referenced_object
    @object.soft_delete(current_user)
    respond_to do |format|
      format.html { render_row_turbo(:close) } if row_html_turbo_allowed?
    end
  end

  # :soft_restore
  def soft_restore
    @update_span = params[:update]
    @object = referenced_object
    @object.soft_restore
    respond_to do |format|
      format.html { render_row_turbo(:close) } if row_html_turbo_allowed?
    end
  end

  # :destroy destroys the record. There is no undo!
  def destroy
    @update_span = params[:update]
    @object = referenced_object
    if destroy_permitted?
      @object.destroy
      # Capture after destroy: `.last` before destroy was the latest *update*
      # (e.g. a plain_text_area edit), so undo reified the pre-edit state.
      @undo_version = @object.versions.last
      respond_to do |format|
        format.html { render_row_turbo_destroyed } if row_html_turbo_allowed?
      end
    end
  end

  # :revert works like undo.
  # Thanks Ryan Bates: http://railscasts.com/episodes/255-undo-with-paper-trail
  #
  # Two reify paths:
  #
  # * Primary version: the reified object IS the row (Apartment, Photo, ...).
  #   Save it and we're done; CarrierWave keeps the previous file on disk
  #   (see app/uploaders/image_uploader.rb) so a restored `image` column
  #   still points at real bytes.
  # * ActionText (rich_text) version: the reified object is the
  #   `ActionText::RichText` row hanging off the parent. Save the rich text,
  #   then `touch` the parent so any timestamp display refreshes. Frame ids
  #   below derive from `@parent` for both branches.
  def revert
    @update_span = params[:update]
    @version = PaperTrail::Version.find(params[:id])
    @parent = revert_authorization_subject(@version)
    authorize!(:revert, @parent || @Klass) if cancan_enabled?
    # Same gate as :destroy (see destroy_permitted?): superadmin when the host
    # has the Devise+roles system, otherwise no extra gate beyond CanCan.
    return head :forbidden unless destroy_permitted?
    return head :not_found unless @parent

    @object = @version.reify(
      has_many: true,
      has_and_belongs_to_many: true,
      belongs_to: true
    )
    # PaperTrail::Version#reify returns nil for `create` events because
    # there is no prior state to roll back to. The versions list view
    # hides the Restore link for `create` rows, but guard here too in
    # case a request was bookmarked or replayed: render close on the
    # current parent without mutating anything.
    if @object.nil?
      # reify returns nil for `create` events (no prior state). For a
      # rich_text create, reverting means "undo the creation" -> destroy
      # the ActionText::RichText row so the parent's field reverts to
      # empty (symmetric with reverting an update on a rich_text that
      # was first saved empty). For a primary record we never offer
      # Restore on `create` in the view; this branch only runs for
      # replayed/bookmarked URLs and must remain a no-op response keyed
      # off the parent.
      item = @version.item
      if defined?(ActionText::RichText) && item.is_a?(ActionText::RichText)
        @rich_text_record = item
        @parent = @rich_text_record.record
        return head :not_found unless @parent
        @rich_text_record.destroy
        @parent.touch if @parent.respond_to?(:touch)
      else
        @parent = item || @parent
        return head :not_found unless @parent
      end
      return render_revert_response if row_html_turbo_allowed?
      return
    end
    if defined?(ActionText::RichText) && @object.is_a?(ActionText::RichText)
      @rich_text_record = @object
      @parent = @rich_text_record.record
      return head :not_found unless @parent
      @rich_text_record.save!
      @parent.touch if @parent.respond_to?(:touch)
    else
      @parent = persist_reverted_primary!(@object)
      restore_rich_texts_for_reverted_parent!(@parent)
      @parent.reload
    end
    render_revert_response if row_html_turbo_allowed?
  end

  private

  # Hard-destroy gate. Generated apps restrict destroy to a Devise user with
  # `role?(:superadmin)` (Role model + roles HABTM). Hosts without that role
  # system (e.g. the engine's test/dummy harness, or apps using a different
  # auth stack) have no gatekeeper here beyond CanCan's
  # `load_and_authorize_resource`; pre-8.1.27 this crashed with
  # `NoMethodError` on `nil.role?` instead of deciding either way.
  def destroy_permitted?
    user = respond_to?(:current_user, true) ? current_user : nil
    return true unless user.respond_to?(:role?)

    user.role?(:superadmin)
  end

  # Persist a reified *primary* record (Apartment, Photo, ...) for +revert+.
  #
  # +reify+ on a +destroy+ version returns a record with +new_record? == true+
  # carrying the original primary key. The normal undo (row currently deleted)
  # path INSERTs that id and is correct. But the versions panel also offers
  # Restore on +destroy+ rows (their changeset is non-empty in apps that track
  # +object_changes+ on destroy), and the post-delete undo banner can be
  # replayed. Once the row has been restored, a blind +save!+ re-INSERTs the
  # existing id and raises +RecordNotUnique+ (SQLite: +UNIQUE constraint failed:
  # photos.id+). Mirror the rich-text upsert (8.1.16): when a row with that PK
  # already exists, copy the reified column values onto it and +save!+ that
  # instead, so reverting is idempotent across repeated delete/undo cycles.
  def persist_reverted_primary!(object)
    klass = object.class
    primary_key = klass.primary_key

    if object.new_record? && object.id.present? && klass.exists?(object.id)
      existing = klass.find(object.id)
      existing.assign_attributes(object.attributes.except(primary_key))
      existing.save!
      existing
    else
      object.save!
      object
    end
  end

  # Undoing a parent +destroy+ reifies the Apartment/Photo row only. ActionText
  # bodies live in +action_text_rich_texts+ and get their own PaperTrail
  # +destroy+ versions; those rows are gone after +parent.destroy+, so we also
  # reify each matching +ActionText::RichText+ destroy snapshot.
  #
  # Use +find_or_initialize_by(record_type, record_id, name)+ and copy +body+
  # only. Reified rows carry the old PK; +save!+ on a new record would INSERT
  # that id and raise +RecordNotUnique+ on a second delete/undo cycle when the
  # row already exists. Only the newest destroy version per attribute name is
  # applied (repeat delete/undo leaves multiple RT destroy versions in the table).
  def restore_rich_texts_for_reverted_parent!(parent)
    return unless defined?(ActionText::RichText)

    record_type = parent.class.base_class.name
    record_id = parent.id
    versions_by_name = {}

    PaperTrail::Version
      .where(item_type: "ActionText::RichText", event: "destroy")
      .order(id: :desc)
      .each do |version|
        attrs = version.object_deserialized
        next unless attrs.is_a?(Hash)

        type = attrs["record_type"] || attrs[:record_type]
        rid = attrs["record_id"] || attrs[:record_id]
        next unless type == record_type && rid.to_i == record_id

        name = (attrs["name"] || attrs[:name]).to_s
        next if name.empty?

        versions_by_name[name] ||= version
      end

    versions_by_name.each_value do |version|
      reified = version.reify
      next unless reified

      name = reified.name.to_s
      record = ActionText::RichText.find_or_initialize_by(
        record_type: record_type,
        record_id: record_id,
        name: name
      )
      record.body = reified.body if reified.respond_to?(:body)
      record.save!
    end
  end

  # +revert+ is excluded from +load_and_authorize_resource+; +authorize!+ runs in the
  # action. +check_authorization+ on ApplicationController still requires that flag.
  def revert_authorization_subject(version)
    reified = version.reify(
      has_many: true,
      has_and_belongs_to_many: true,
      belongs_to: true
    )
    if defined?(ActionText::RichText) && reified.is_a?(ActionText::RichText)
      return reified.record
    end
    return reified if reified

    item = version.item
    if defined?(ActionText::RichText) && item.is_a?(ActionText::RichText)
      return item.record
    end
    return item if item

    klass = version.item_type.safe_constantize
    return nil unless klass && version.item_id

    klass.new(id: version.item_id)
  end

  def render_revert_response
    respond_to do |format|
      format.turbo_stream { render_revert_turbo_streams }
    end
  end

  # Versions list lives in +<turbo-frame id="…_versions">+; POST +restore+ would otherwise
  # send +Turbo-Frame: …_versions+ while +row_close+ only returns the row frame. Stream
  # replaces both the row and the versions panel in one response.
  def render_revert_turbo_streams
    row_id = helpers.inline_forms_row_turbo_frame_id(@parent)
    versions_id = helpers.inline_forms_versions_turbo_frame_id(@parent)
    row_html = render_to_string(
      "inline_forms/row_close",
      layout: false,
      formats: [:html],
      locals: { update_span: row_id, object: @parent, inline_forms_turbo_row: true }
    )
    versions_html = render_to_string(
      "inline_forms/versions_panel",
      layout: false,
      formats: [:html],
      locals: { update_span: versions_id, object: @parent, inline_forms_turbo_row: true }
    )
    render turbo_stream: [
      turbo_stream.replace(row_id, row_html),
      turbo_stream.replace(versions_id, versions_html)
    ]
  end

  # HTML field edit/show inside a +<turbo-frame>+ (Step 3). Scalar fields no longer
  # use UJS; +format.html+ is always registered for edit/update/single-attribute show.
  #
  # +@inline_forms_turbo_field+ tells +link_to_inline_edit+ (and the per-+form_element+
  # +*_show+ helpers it wraps) to emit Turbo data attributes. The flag is set in
  # +_show.html.erb+ when a row first opens, but bare +field_show+ / +field_edit+
  # responses (on +cancel+ / +update+) do not re-render +_show+. Without setting
  # it here the link in the swapped frame would not target the field frame and
  # inline edit would not open reliably.
  def render_turbo_field(template, turbo_field_show: false)
    @turbo_frame = true if template == :field_edit
    @turbo_field_show_turbo_frame = turbo_field_show
    @inline_forms_turbo_field = true
    render "inline_forms/#{template}", layout: "turbo_rails/frame"
  end

  # Top-level list row open/close (Step 3): full `_show` / `_close` inside
  # `<turbo-frame id="…">` matching `params[:update]`.
  def render_row_turbo(mode)
    @inline_forms_turbo_row = true
    template = (mode == :close) ? "inline_forms/row_close" : "inline_forms/row_show"
    layout = turbo_frame_request? ? "turbo_rails/frame" : "inline_forms"
    render template, layout: layout
  end

  def render_row_turbo_destroyed
    @inline_forms_turbo_row = true
    layout = turbo_frame_request? ? "turbo_rails/frame" : "inline_forms"
    render "inline_forms/row_destroyed", layout: layout
  end

  # Nested has_many +new+ / cancel / +create+ inside a parent +<turbo-frame>+ (e.g. Apartment → Photo).
  def html_list_flow_allowed?
    params[:update].present? && (@parent_class.present? || !@Klass.not_accessible_through_html?)
  end

  def associated_list_html_allowed?
    @parent_class.present? && params[:update].present?
  end

  def list_frame_id?(update)
    update.present? && update.to_s.end_with?("_list")
  end

  def render_list_frame_after_save
    @ul_needed = true
    render "inline_forms/create_list_frame", layout: associated_list_frame_layout
  end

  def associated_list_frame_layout
    # Use full inline_forms chrome so the swapped frame is styled; Turbo extracts
    # the matching <turbo-frame id="…"> from the response body.
    "inline_forms"
  end

  def render_turbo_new
    @turbo_frame = true
    render "inline_forms/new_record", layout: associated_list_frame_layout
  end

  # Nested +index+ / cancel / +create+ HTML inside a parent-associated +<turbo-frame>+.
  def render_nested_associated_list_html
    if turbo_frame_request? && nested_list_frame_id?(params[:update])
      # Pagination and other swaps targeting the inner +…_photos_list+ frame: minimal layout.
      @ul_needed = true
      render "inline_forms/_list", layout: "turbo_rails/frame"
    elsif turbo_frame_request? && params[:update].present?
      # Cancel / +create+ targeting the outer +apartment_<id>_photos+ frame: styled full layout.
      render_associated_list_frame
    else
      frame_layout = turbo_frame_request? ? "turbo_rails/frame" : "inline_forms"
      render "inline_forms/_list", layout: frame_layout
    end
  end

  # +apartment_1_photos_list+ (inner list) vs +apartment_1_photos+ (outer associated container).
  def nested_list_frame_id?(update)
    update.to_s.end_with?("_list")
  end

  # After nested +create+ / cancel; restores list inside the outer associated frame.
  def render_associated_list_frame
    @ul_needed = true
    render "inline_forms/create_list_frame", layout: associated_list_frame_layout
  end

  # HTML row open/close is allowed for normal models, and for +not_accessible_through_html?+
  # models (e.g. Photo) when the request targets a nested associated list row
  # (+params[:update]+ like +apartment_1_photo_5+), not bare top-level CRUD.
  def row_html_turbo_allowed?
    return true unless @Klass.not_accessible_through_html?
    nested_associated_list_row_update?(params[:update])
  end

  # +apartment_1_photo_5+ → +["apartment","1","photo","5"]+ (≥4 segments, trailing id).
  # Differs from field spans (+apartment_1_photo_5_name+ ends with letters) and
  # top-level rows (+apartment_1+ — too few segments).
  def nested_associated_list_row_update?(update)
    parts = update.to_s.split("_")
    parts.length >= 4 && parts.last.match?(/\A\d+\z/)
  end

  # Get the class from the controller name.
  # CountryController < InlineFormsController, so what class are we?
  # TODO think about this a bit more.
  def getKlass #:doc:
    @Klass = self.controller_name.classify.constantize
    InlineForms.validate_plain_text_configuration_for!(@Klass)
    @Klass
  end

  def referenced_object
    @Klass.find(object_id_params)
  end

  def object_id_params
    params.require(:id)
  end

  def revert_params
    params.require(:id).permit(:update)
  end

end
