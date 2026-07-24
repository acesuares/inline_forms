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
        table = table_name
        clause = cols.map { |c|
          "#{connection.quote_table_name(table)}.#{connection.quote_column_name(c)} LIKE :q"
        }.join(" OR ")
        scope :inline_forms_search, ->(q) {
          where(clause, q: "%#{sanitize_sql_like(q.to_s)}%")
        }
      end
    end
  end
end
