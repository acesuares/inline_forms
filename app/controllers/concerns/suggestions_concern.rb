# frozen_string_literal: true

# The JSON behind a search field's suggestions (suggest_field_tag +
# inline_forms/datalist_suggest.js). InlineFormsController includes it; any
# other controller may include it too. suggest_names and
# inline_forms_suggestion_scope / inline_forms_readable_columns ask
# `cancan_enabled?`: outside InlineFormsController include CancanConcern
# as well (render_inline_forms_suggestions alone needs nothing):
#
#   suggest_names :client, :last_name                 # term anywhere in the name
#   suggest_names :client, :first_name, match: :start # only at the start
#   suggest_names :member, :last_name, scope: ->(members) { members.where(active: true) }
#   suggest_names :document, :subject, scope: :incoming, order: :relation # newest first
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
# on; `scope:` narrows them further: a named scope (Symbol), or a lambda run
# in the controller (instance_exec) with the relation; either returns a
# relation. `order: :relation` keeps that relation's order (8.1.86).
#
# For an action of your own, three private helpers are supported API
# (Papiamentu, RACVS and yavetracker build on them):
#
#   inline_forms_suggestion_scope(model)          the records the user may read
#   inline_forms_readable_columns(model, columns) the columns the user may read
#   render_inline_forms_suggestions(values)       the JSON answer
#
#   def autocomplete_word_name
#     names = inline_forms_suggestion_scope(Word).where(language: current_language)
#     render_inline_forms_suggestions InlineForms::Suggestions.values(
#       names, inline_forms_readable_columns(Word, [ :name ]), params[:term], match: :start)
#   end
module SuggestionsConcern
  extend ActiveSupport::Concern

  class_methods do
    def suggest_names(model_name, column, match: :contains, limit: InlineForms::Suggestions::LIMIT, scope: nil,
                      order: :alphabetical)
      match = InlineForms::Suggestions.check_match!(match)
      order = InlineForms::Suggestions.check_order!(order)
      InlineForms::Suggestions.check_limit!(limit)
      unless scope.nil? || scope.respond_to?(:call) || scope.is_a?(Symbol)
        raise ArgumentError, "scope: must be a Symbol (a named scope) or a lambda, not #{scope.inspect}"
      end

      define_method("autocomplete_#{model_name}_#{column}") do
        model = model_name.to_s.camelize.constantize
        names = inline_forms_suggestion_scope(model)
        names = inline_forms_apply_suggestion_scope(names, scope) if scope
        render_inline_forms_suggestions InlineForms::Suggestions.values(
          names, inline_forms_readable_columns(model, [ column ]), params[:term],
          match: match, limit: limit, order: order
        )
      end
    end
  end

  private

  # scope: a Symbol is a named scope of the model (`:incoming`), a lambda runs
  # in the controller with the relation. Either must give a relation.
  def inline_forms_apply_suggestion_scope(names, scope)
    scoped = scope.is_a?(Symbol) ? names.public_send(scope) : instance_exec(names, &scope)
    return scoped if scoped.is_a?(ActiveRecord::Relation)

    raise ArgumentError, "suggest_names scope: #{scope.inspect} gave #{scoped.class}, not a relation"
  end

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
