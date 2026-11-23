# frozen_string_literal: true

module InlineForms
  # Text suggestions for a search field: the values of one or more columns
  # that match what the user typed, for the browser's own <datalist>
  # (suggest_field_tag + inline_forms/datalist_suggest.js). Used by the
  # controller macro `suggest_names` (SuggestionsConcern) and by the engine's
  # search box for a model with `inline_forms_search_on …, suggest: …`.
  #
  # How a value matches the term (`match:`), case ignored, % and _ in the term
  # taken literally:
  #
  #   :contains  anywhere in the value ("ma" finds Martina, Tinamart, Tima)
  #   :start     at the start of the value ("ma" finds Martina only)
  #   :word      at the start of any word ("ma" finds Martina, Anna Maria)
  #
  # The answer: at most `limit` values, each once (compared stripped and in any
  # case, the first in A-Z order kept), in case-insensitive A-Z order. An empty
  # term gives [].
  module Suggestions
    MATCHES = %i[contains start word].freeze
    LIMIT = 12

    module_function

    # Raises ArgumentError for an unknown match; returns it as a Symbol.
    def check_match!(match)
      match = match.to_sym
      return match if MATCHES.include?(match)

      raise ArgumentError, "match: must be one of #{MATCHES.map(&:inspect).join(', ')}, not #{match.inspect}"
    end

    def check_limit!(limit)
      return limit if limit.is_a?(Integer) && limit.positive?

      raise ArgumentError, "limit: must be a positive Integer, not #{limit.inspect}"
    end

    # relation: what the user may see (already `accessible_by`, scoped, …).
    def values(relation, columns, term, match: :contains, limit: LIMIT)
      match = check_match!(match)
      limit = check_limit!(limit)
      term = term.to_s.strip
      return [] if term.empty?

      columns = Array(columns)
      found = columns.flat_map { |column| column_values(relation, column, term, match, limit) }
      found = found.map(&:to_s).reject(&:empty?)
      # One column: the database's order (its collation, e.g. accents with
      # their letter). Several: merged here.
      found = found.sort_by { |value| [ value.downcase, value ] } if columns.size > 1
      found.uniq(&:downcase).first(limit)
    end

    # SELECT MIN(TRIM(value)) … GROUP BY LOWER(TRIM(value)) ORDER BY that:
    # one row per value as the user sees it, so the limit counts distinct
    # names ('Adriana', 'adriana ' and 'Adriana' are one). A plain DISTINCT
    # would keep them apart (case, and MySQL's NO PAD collations keep a
    # trailing space) and fill the limit with them. Valid under MySQL's
    # ONLY_FULL_GROUP_BY and in PostgreSQL. reorder drops a default or list
    # order the relation brings.
    def column_values(relation, column, term, match, limit)
      model = relation.model
      attribute = model.arel_table[column.to_s]
      lowered = Arel::Nodes::NamedFunction.new("LOWER", [ attribute ])
      key = Arel::Nodes::NamedFunction.new("LOWER", [ Arel::Nodes::NamedFunction.new("TRIM", [ attribute ]) ])
      condition = patterns(model, term, match).map { |pattern|
        lowered.matches(Arel::Nodes::NamedFunction.new("LOWER", [ Arel::Nodes.build_quoted(pattern) ]), "\\", true)
      }.reduce(:or)
      relation.where(condition).unscope(:select).group(key).reorder(key.asc).limit(limit)
              .pluck(Arel::Nodes::Min.new([ Arel::Nodes::NamedFunction.new("TRIM", [ attribute ]) ]))
    end

    def patterns(model, term, match)
      escaped = model.sanitize_sql_like(term, "\\")
      case match
      when :contains then [ "%#{escaped}%" ]
      when :start    then [ "#{escaped}%" ]
      when :word     then [ "#{escaped}%", "% #{escaped}%" ]
      end
    end
  end
end
