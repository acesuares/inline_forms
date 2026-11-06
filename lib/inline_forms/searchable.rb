# frozen_string_literal: true

module InlineForms
  # Opt-in list search for inline_forms index views. Models declare searchable
  # columns with `inline_forms_search_on :col, …`; only those models get the
  # engine's generic search box (or a bespoke `_<model>_search` partial).
  module Searchable
    extend ActiveSupport::Concern

    class_methods do
      def inline_forms_searchable?
        @inline_forms_searchable == true
      end

      def inline_forms_search_on(*columns)
        cols = columns.flatten.map(&:to_s)
        if cols.empty?
          raise ArgumentError, "inline_forms_search_on requires at least one column"
        end

        @inline_forms_searchable = true
        @inline_forms_search_columns = cols
        model = self
        scope :inline_forms_search, ->(q) {
          where(model.inline_forms_search_clause, q: "%#{sanitize_sql_like(q.to_s)}%")
        }
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
