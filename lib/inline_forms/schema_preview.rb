# -*- encoding : utf-8 -*-

module InlineForms
  # Cheap preview of a SchemaIntent, WITHOUT running a migration or booting a
  # second app. The trick (see the staging doc): declare the proposed attribute
  # as a *virtual* typed attribute on a throwaway subclass of the target model,
  # so it reads/writes in memory with no column, and render the stock inline
  # forms against an AttributeList that has the proposed row spliced in at the
  # requested position. The real class and its table are untouched.
  #
  #   obj, list = InlineForms::SchemaPreview.build(intent, existing_record)
  #   # render "inline_forms/show" with @object = obj,
  #   #   @inline_forms_attribute_list = list  (the controller already supports
  #   #   this per-request override — see attr_writer :inline_forms_attribute_list)
  #
  # Scope of the stab: scalar attributes preview fully. Relation dropdowns
  # (backed by a foreign key + association) and uploader/rich_text fields need
  # model-side wiring the preview does not synthesize; #supported? reports this
  # so a caller can fall back to a "available after apply" placeholder.
  module SchemaPreview
    module_function

    # Map an AR column type (from the engine's form-element maps) to an
    # ActiveModel::Type symbol for a virtual attribute.
    COLUMN_TYPE_TO_VIRTUAL = {
      string: :string,
      text: :string,
      integer: :integer,
      decimal: :decimal,
      float: :float,
      boolean: :boolean,
      date: :date,
      time: :time,
      datetime: :datetime,
      timestamp: :datetime
    }.freeze

    # Column-backed elements a virtual attribute alone cannot faithfully
    # preview: uploaders need a mounted CarrierWave uploader; money_field a
    # monetize declaration; devise_password_field a Devise model; pdf_link a
    # route. The stab reports these as unsupported so a caller shows an
    # "available after apply" placeholder instead of a broken field.
    PREVIEW_UNSUPPORTED_FORM_ELEMENTS = %i[
      image_field
      audio_field
      file_field
      multi_image_field
      simple_file_field
      pdf_link
      money_field
      devise_password_field
    ].freeze

    # Returns [preview_object, attribute_list]. `base_record` seeds the preview
    # object's existing attributes when given (so the rest of the form shows
    # real data); otherwise a blank instance is used.
    def build(intent, base_record = nil)
      base_class = intent.model_class
      list       = attribute_list_for(base_class, intent)
      preview    = preview_class_for(base_class, intent)

      object = base_record ? preview.new(base_record.attributes) : preview.new
      object.inline_forms_attribute_list = list
      [ object, list ]
    end

    # False when the intent's form element needs model-side wiring the preview
    # cannot synthesize (relations, uploaders, rich_text).
    def supported?(intent)
      !virtual_type(intent.form_element).nil?
    end

    # The AttributeList the preview should render: the model's current list with
    # the proposed row inserted at --after/--before (falling back to append).
    def attribute_list_for(base_class, intent)
      current = base_class.new.inline_forms_attribute_list
      list    = InlineForms::AttributeList.wrap(current.map(&:dup))
      opts    = { values: intent.values, disabled: intent.disabled }.compact

      if intent.after && list.include_attribute?(intent.after)
        list.insert_after(intent.after, intent.attribute, intent.form_element, **opts)
      elsif intent.before && list.include_attribute?(intent.before)
        list.insert_before(intent.before, intent.attribute, intent.form_element, **opts)
      else
        list.field(intent.attribute, intent.form_element, **opts)
      end
      list
    end

    # A throwaway subclass with the proposed attribute declared virtual (when
    # supported), masquerading as the base class so partials/routes resolve.
    def preview_class_for(base_class, intent)
      type = virtual_type(intent.form_element)
      klass = Class.new(base_class)
      klass.attribute(intent.attribute, type) if type

      base_name       = base_class.name
      base_model_name = base_class.model_name
      klass.define_singleton_method(:name) { base_name }
      klass.define_singleton_method(:model_name) { base_model_name }
      klass
    end

    def virtual_type(form_element)
      fe = form_element.to_sym
      return nil if PREVIEW_UNSUPPORTED_FORM_ELEMENTS.include?(fe)

      column_type =
        InlineForms::SPECIAL_COLUMN_TYPES[fe] ||
        (InlineForms::DEFAULT_FORM_ELEMENTS.value?(fe) ? :string : nil)
      return nil if column_type.nil? || column_type == :no_migration || column_type == :belongs_to

      COLUMN_TYPE_TO_VIRTUAL[column_type]
    end
  end
end
