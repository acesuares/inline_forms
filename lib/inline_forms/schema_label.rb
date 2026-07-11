# -*- encoding : utf-8 -*-

require "yaml"
require "fileutils"

module InlineForms
  # Writes a human label for a model attribute (or header) into a locale file,
  # so `human_attribute_name` renders it. Used by the schema GUI's optional
  # "Label" field. Like the header/field edits, this is a code/config change
  # that lands in the working tree (git-tracked) — never the DB.
  #
  # The label is merged (not clobbered) into
  #   config/locales/inline_forms_labels.<locale>.yml
  # under the key inline_forms renders from:
  #   <locale>: activerecord: attributes: <model_i18n_key>: <attribute>: "Label"
  #
  # A dedicated file (rather than editing an existing app locale file) keeps the
  # write a whole-document load -> deep_merge -> dump, which is robust against
  # comments/formatting concerns.
  module SchemaLabel
    module_function

    def file_path(destination_root, locale)
      File.join(destination_root.to_s, "config", "locales", "inline_forms_labels.#{locale}.yml")
    end

    def i18n_key_for(model_class)
      if model_class.respond_to?(:model_name)
        model_class.model_name.i18n_key.to_s
      else
        model_class.to_s.underscore
      end
    end

    # Merge the label into the locale file and return its path.
    def write(destination_root:, model_class:, attribute:, label:, locale:)
      path      = file_path(destination_root, locale)
      key       = i18n_key_for(model_class)
      existing  = load_document(path)
      addition  = {
        locale.to_s => {
          "activerecord" => {
            "attributes" => {
              key => { attribute.to_s => label.to_s }
            }
          }
        }
      }
      merged = existing.deep_merge(addition)

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, merged.to_yaml)
      path
    end

    def load_document(path)
      return {} unless File.exist?(path)

      loaded = YAML.safe_load(File.read(path))
      loaded.is_a?(Hash) ? loaded : {}
    rescue StandardError
      {}
    end
  end
end
