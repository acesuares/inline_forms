# -*- encoding : utf-8 -*-
module InlineForms
  class ArchivedFormElementError < StandardError; end

  # Retired form-element symbols. Full source for entries with +archive_path+ lives
  # under archived/form_elements/<name>/ — see archived/README.md.
  ARCHIVED_FORM_ELEMENTS = {
    geo_code_curacao: {
      archived_in_version: "7.6.0",
      archive_path: "archived/form_elements/geo_code_curacao",
      summary: "Curaçao street geocode (MySQL Zones/Buurten/Straatcode, jQuery autocomplete, UJS list_streets).",
    },
    chicas_photo_list: {
      archived_in_version: "7.6.0",
      archive_path: "archived/form_elements/chicas",
      summary: "Chicas app read-only member photo gallery (show-only).",
    },
    chicas_family_photo_list: {
      archived_in_version: "7.6.0",
      archive_path: "archived/form_elements/chicas",
      summary: "Chicas app read-only family member photo gallery (show-only).",
    },
    chicas_dropdown_with_family_members: {
      archived_in_version: "7.6.0",
      archive_path: "archived/form_elements/chicas",
      summary: "Chicas client picker via family.clients; moves CarrierWave upload dir on update.",
    },
    kansen_slider: {
      archived_in_version: "7.6.0",
      archive_path: "archived/form_elements/kansen_slider",
      summary: "jQuery UI slider for integer-coded chance scale; uses model attribute_values.",
    },
    tree: {
      archived_in_version: "7.7.0",
      archive_path: "archived/form_elements/tree",
      summary: "Self-referential children list via parent.children; requires host tree APIs (see README).",
    },
    move: {
      archived_in_version: "7.7.0",
      archive_path: "archived/form_elements/tree",
      summary: "Reparent via hash_tree_to_collection + add_child (host must implement; pairs with :tree).",
    },
    absence_list: {
      removed_in_version: "6.3.0",
      archive_path: nil,
      summary: "Project-specific absence list UI; removed without a copy in this repo (see CHANGELOG 6.3.0).",
    },
    ckeditor: {
      archived_in_version: "8.1.21",
      archive_path: "archived/form_elements/ckeditor",
      summary: "Legacy CKEditor form element; use :rich_text (ActionText) instead.",
    },
    text_area_without_ckeditor: {
      archived_in_version: "8.1.21",
      archive_path: "archived/form_elements/ckeditor",
      summary: "Legacy plain-text alias; use :plain_text or :plain_text_area instead.",
    },
  }.freeze

  def self.validate_no_archived_form_elements_for!(klass)
    return unless klass.instance_methods.include?(:inline_forms_attribute_list)

    klass.new.inline_forms_attribute_list.each do |attribute, form_element|
      key = form_element.to_sym
      next unless ARCHIVED_FORM_ELEMENTS.key?(key)

      meta = ARCHIVED_FORM_ELEMENTS[key]
      version = meta[:archived_in_version] || meta[:removed_in_version]
      hint = if meta[:archive_path]
        "Restore from #{meta[:archive_path]}/README.md or vendor into your app."
      else
        "See archived/README.md and CHANGELOG #{version}."
      end

      raise ArchivedFormElementError,
        "#{klass.name} inline_forms_attribute_list declares #{attribute}:#{form_element}, " \
        "which was retired in inline_forms #{version} (#{meta[:summary]}). #{hint}"
    end
  end
end
