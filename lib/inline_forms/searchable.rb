# frozen_string_literal: true

module InlineForms
  # Opt-in list search for inline_forms index views. Models declare searchable
  # columns with `inline_forms_search_on :col, …`; only those models get the
  # engine's generic search box (or a bespoke `_<model>_search` partial).
  #
  # `suggest:` gives that search box suggestions while the user types (the
  # browser's own list, see InlineForms::Suggestions), from the records the
  # user may see in the list:
  #
  #   inline_forms_search_on :name, :email, suggest: true                # from both columns
  #   inline_forms_search_on :name, :email, suggest: { on: :name, match: :start, limit: 8 }
  #
  # `on:` (default: the search columns), `match:` (:contains, the default,
  # :start or :word) and `limit:` (12). The search itself still finds the
  # text anywhere in any search column.
  module Searchable
    extend ActiveSupport::Concern

    class_methods do
      def inline_forms_searchable?
        @inline_forms_searchable == true
      end

      # nil, or { on: [columns], match:, limit: }.
      def inline_forms_suggestions
        @inline_forms_suggestions
      end

      def inline_forms_search_on(*columns, suggest: nil)
        cols = columns.flatten.map(&:to_s)
        if cols.empty?
          raise ArgumentError, "inline_forms_search_on requires at least one column"
        end

        @inline_forms_searchable = true
        @inline_forms_search_columns = cols
        @inline_forms_suggestions = inline_forms_suggest_options(suggest, cols)
        model = self
        scope :inline_forms_search, ->(q) {
          where(model.inline_forms_search_clause, q: "%#{sanitize_sql_like(q.to_s)}%")
        }
      end

      def inline_forms_suggest_options(suggest, search_columns)
        return nil if suggest.nil? || suggest == false

        options = suggest == true ? {} : suggest
        unless options.is_a?(Hash)
          raise ArgumentError, "inline_forms_search_on suggest: takes true or a Hash (on:, match:, limit:), not #{suggest.inspect}"
        end

        unknown = options.keys.map(&:to_sym) - %i[on match limit]
        raise ArgumentError, "inline_forms_search_on suggest: unknown option #{unknown.first.inspect}" if unknown.any?

        options = options.transform_keys(&:to_sym)
        on = Array(options.fetch(:on, search_columns)).map(&:to_s)
        raise ArgumentError, "inline_forms_search_on suggest: on: needs at least one column" if on.empty?

        {
          on: on.freeze,
          match: Suggestions.check_match!(options.fetch(:match, :contains)),
          limit: Suggestions.check_limit!(options.fetch(:limit, Suggestions::LIMIT))
        }.freeze
      end

      # Built on the first search, not in inline_forms_search_on: quoting
      # needs a database connection, and the class body runs whenever the
      # model loads (eager loading, assets:precompile without a database).
      def inline_forms_search_clause
        @inline_forms_search_clause ||= @inline_forms_search_columns.map { |c|
          "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(c)} LIKE :q"
        }.join(" OR ")
      end
    end
  end
end
