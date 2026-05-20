# frozen_string_literal: true

module InlineForms
  # Read-only adapter for the +translations+ SQL view created by the installer
  # (+inline_forms_create_view_for_translations+). The view exposes +thekey+
  # (not +key+) so it works on MySQL where +key+ is reserved.
  class TranslationRecord < ActiveRecord::Base
    self.table_name = "translations"

    def readonly?
      true
    end
  end
end
