# frozen_string_literal: true

# The JSON behind a search field's suggestions (suggest_field_tag +
# inline_forms/datalist_suggest.js). In a controller that inherits from
# InlineFormsController:
#
#   suggest_names :client, :last_name                 # term anywhere in the name
#   suggest_names :client, :first_name, match: :start # only at the start
#   suggest_names :member, :last_name, scope: ->(members) { members.where(active: true) }
#
# defines the action `autocomplete_<model>_<column>` (the name
# rails-jquery-autocomplete's `autocomplete` macro used), which answers
# GET …?term=… with a JSON array of at most `limit` (12) names: see
# InlineForms::Suggestions for `match:` (:contains, :start, :word) and the
# order. The app adds the route and the ability, as for any other action:
#
#   resources :clients do
#     get :autocomplete_client_last_name, on: :collection
#   end
#   can :autocomplete_client_last_name, Client
#
# Only names of records the user may read (`accessible_by`), and only from a
# column the user may read (`can?(:read, Model, :column)`), when CanCan is
# on; `scope:` narrows them further, run in the controller (instance_exec)
# with the relation, and returns a relation.
module SuggestionsConcern
  extend ActiveSupport::Concern

  class_methods do
    def suggest_names(model_name, column, match: :contains, limit: InlineForms::Suggestions::LIMIT, scope: nil)
      match = InlineForms::Suggestions.check_match!(match)
      InlineForms::Suggestions.check_limit!(limit)
      define_method("autocomplete_#{model_name}_#{column}") do
        model = model_name.to_s.camelize.constantize
        names = inline_forms_suggestion_scope(model)
        names = instance_exec(names, &scope) if scope
        render_inline_forms_suggestions InlineForms::Suggestions.values(
          names, inline_forms_readable_columns(model, [ column ]), params[:term], match: match, limit: limit
        )
      end
    end
  end

  private

  def inline_forms_suggestion_scope(model)
    cancan_enabled? ? model.accessible_by(current_ability) : model.all
  end

  # The columns whose values this user may read: `accessible_by` only picks
  # the rows, and a field rule (`cannot :read, User, :email`, as _show asks
  # with can?(:read, record, attribute)) must not leak through suggestions.
  def inline_forms_readable_columns(model, columns)
    return Array(columns) unless cancan_enabled?

    Array(columns).select { |column| can?(:read, model, column.to_sym) }
  end

  # A JSON string, so a serializer gem (active_model_serializers 0.9) does
  # not wrap the array.
  def render_inline_forms_suggestions(values)
    render json: values.to_json
  end
end
