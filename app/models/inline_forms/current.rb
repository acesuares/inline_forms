# -*- encoding : utf-8 -*-

# Per-request actor for model-level file bookkeeping (InlineForms::StoredFiles
# records who uploaded / removed / replaced a file). Set by the engine's
# controllers; nil in the console, seeds and the retention sweep.
class InlineForms::Current < ActiveSupport::CurrentAttributes
  attribute :user_id
end
