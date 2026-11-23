# frozen_string_literal: true

class WidgetsController < InlineFormsController
  # Search suggestions (test/integration/suggestions_test.rb): the default
  # match, and a scope of the controller's own.
  suggest_names :widget, :name, scope: ->(widgets) { widgets.where.not(name: hidden_widget_name) }

  private

  def hidden_widget_name = "Hidden"
end
