# frozen_string_literal: true

class MembersController < InlineFormsController
  # Search suggestions (test/integration/suggestions_test.rb).
  suggest_names :member, :name, match: :start
end
