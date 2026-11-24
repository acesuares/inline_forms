# frozen_string_literal: true

# `inline_forms_suggestion_request?`: true when this request is an
# inline_forms list's search-box suggestions (index with ?suggest=1&term=…,
# which answers a JSON array), not a list view. For an app's own callbacks,
# e.g. statistics that count list views only:
#
#   skip_after_action :track_action, if: :inline_forms_suggestion_request?
#
# Included in InlineFormsController and in InlineFormsApplicationController,
# so an ApplicationController that inherits from the latter has it for every
# controller (false outside the inline_forms lists).
module SuggestionRequestConcern
  extend ActiveSupport::Concern

  included do
    helper_method :inline_forms_suggestion_request?
  end

  protected

  def inline_forms_suggestion_request?
    is_a?(InlineFormsController) && action_name == "index" &&
      params.key?(:suggest) && params[:parent_class].blank?
  end
end
