# frozen_string_literal: true

# Declared file slots (InlineForms::StoredFiles), shaped like StProject's
# Client: two slots with the default column naming (`filename` -> data /
# content_type, `plan_filename` -> plan_data / plan_content_type). An
# ApplicationRecord subclass on purpose: has_paper_trail is inherited, so the
# slot columns' skip must be set on Document without leaking to Widget.
# See test/integration/file_slots_test.rb.
class Document < ApplicationRecord
  include InlineForms::StoredFiles

  inline_forms_file :filename
  inline_forms_file :plan_filename

  # StProject's Attachment/Incident/Zorgformulier validate the filename; a
  # test switches this on to prove undo-of-destroy puts files back BEFORE save.
  cattr_accessor :require_filename, default: false
  validates :filename, presence: true, if: -> { self.class.require_filename }

  validates :title, presence: true

  def _presentation
    "#{title}"
  end

  def inline_forms_attribute_list
    @inline_forms_attribute_list ||= [
      [ :title, :text_field ],
      [ :filename, :simple_file_field ],
      [ :plan_filename, :simple_file_field ]
    ]
  end
end
