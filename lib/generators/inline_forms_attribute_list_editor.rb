# frozen_string_literal: true

require "prism"

module InlineForms
  # Adds a row to the `@inline_forms_attribute_list ||= [ ... ]` literal in a
  # model's source (used by `rails g inline_forms_addto`).
  #
  # The list is located with Prism, Ruby's own parser, so a row is whatever Ruby
  # says is an element of the array: rows over several lines, several rows on
  # one line, `.freeze`, conditional rows, splats, and brackets or `#` in a
  # label or a comment are all just elements. The result is parsed again before
  # it is returned; what cannot be placed raises Unplaceable and the caller
  # leaves the file alone.
  #
  # Style of what is written (RuboCop omakase): a comma between rows, none after
  # the last one.
  class AttributeListEditor
    class Unplaceable < StandardError; end

    # attribute_list rows with these names, or with the :info element, start the
    # trailing "metadata" block: new rows go above it by default.
    METADATA_ROW_NAMES = %w[created_at updated_at].freeze
    COMMENTED_ROW = /\A[ \t]*#[ \t]*\[[ \t]*:/

    def initialize(source)
      @source = source
      @bytes = source.b
      parsed = Prism.parse(source)
      raise Unplaceable, "the file has a syntax error" if parsed.errors.any?

      @array = find_array(parsed.value)
      @elements = @array ? @array.elements : []
    end

    # false when the model has no such list, e.g. it inherits one.
    def list?
      !@array.nil?
    end

    def row?(name)
      !index_of(name).nil?
    end

    # Returns [ new_source, note ]. +after+ / +before+ name an existing row; the
    # caller checks with row? that it exists.
    def insert(row, after: nil, before: nil)
      raise Unplaceable, "there is no inline_forms_attribute_list" unless list?

      edits, note = plan(row, after: after, before: before)
      result = apply(edits)
      verify!(result)
      [ result, note ]
    end

    private

    def plan(row, after:, before:)
      return [ after_element(index_of(after), row), " (after :#{after})" ] if after
      return [ before_element(index_of(before), row), " (before :#{before})" ] if before
      return [ only_element(row), "" ] if @elements.empty?
      if (metadata = metadata_start_index)
        return [ before_element(metadata, row), " (above metadata)" ]
      end

      last_row = @elements.rindex { |element| row_symbols(element).any? } || @elements.size - 1
      [ after_element(last_row, row), "" ]
    end

    # An edit is [ byte offset, text to insert, bytes to replace ].
    def after_element(index, row)
      element_end = @elements[index].location.end_offset
      last = index == @elements.size - 1
      following = last ? @array.closing_loc.start_offset : @elements[index + 1].location.start_offset
      comma_end = comma_end_between(element_end, following)
      position = comma_end || element_end
      comma = comma_end ? "" : ","
      separator = last ? "" : ","

      line_end = @bytes.index("\n", position)
      return [ [ position, "#{comma} #{row}#{separator}", 0 ] ] if line_end.nil? || line_end >= following

      edits = comma_end ? [] : [ [ element_end, comma, 0 ] ]
      position = line_end + 1
      # Rows that are commented out below the last one keep the comma they have.
      position = skip_commented_rows(position, following) if last
      edits << [ position, "#{indent}#{row}#{separator}\n", 0 ]
    end

    def before_element(index, row)
      start = @elements[index].location.start_offset
      lead = line_lead(start)
      return [ [ start - lead.bytesize, "#{lead}#{row},\n", 0 ] ] if lead

      [ [ start, "#{row}, ", 0 ] ]
    end

    def only_element(row)
      closing = @array.closing_loc.start_offset
      lead = line_lead(closing)
      return [ [ closing - lead.bytesize, "#{indent}#{row}\n", 0 ] ] if lead

      opening_end = @array.opening_loc.end_offset
      [ [ opening_end, "\n#{indent}#{row}\n#{base_indent}", closing - opening_end ] ]
    end

    def apply(edits)
      result = @bytes.dup
      edits.sort_by(&:first).reverse_each do |position, text, length|
        result[position, length] = text.b
      end
      result.force_encoding(@source.encoding)
    end

    def verify!(result)
      edited = self.class.new(result)
      return if edited.send(:element_count) == @elements.size + 1

      raise Unplaceable, "the row would not become one element of the list"
    end

    def element_count
      @elements.size
    end

    def find_array(node)
      queue = [ node ]
      until queue.empty?
        current = queue.shift
        if current.is_a?(Prism::InstanceVariableOrWriteNode) && current.name == :@inline_forms_attribute_list
          array = leftmost_array(current.value)
          return array if array
        end
        queue.concat(current.compact_child_nodes)
      end
      nil
    end

    # The array literal in `[ ... ]`, `[ ... ].freeze` or `[ ... ] + MORE`.
    def leftmost_array(node)
      node = node.receiver while node.is_a?(Prism::CallNode)
      node if node.is_a?(Prism::ArrayNode) && node.opening_loc&.slice == "["
    end

    # [ name, form element ] of a row as strings; empty for anything else.
    def row_symbols(element)
      array = leftmost_array(element)
      return [] unless array

      symbols = array.elements.first(2)
      return [] unless symbols.first.is_a?(Prism::SymbolNode)

      symbols.map { |node| node.unescaped if node.is_a?(Prism::SymbolNode) }
    end

    def index_of(name)
      @elements.index { |element| row_symbols(element).first == name.to_s }
    end

    # A `:header` right above the first metadata row belongs to the block.
    def metadata_start_index
      first = @elements.index do |element|
        name, form_element = row_symbols(element)
        form_element == "info" || METADATA_ROW_NAMES.include?(name)
      end
      return nil unless first

      first.positive? && row_symbols(@elements[first - 1])[1] == "header" ? first - 1 : first
    end

    # Between two elements there are only commas, whitespace and comments, but a
    # comment may contain a comma: ask the lexer.
    def comma_end_between(from, to)
      @commas ||= Prism.lex(@source).value.filter_map do |token, _state|
        token.location if token.type == :COMMA
      end
      @commas.find { |comma| comma.start_offset >= from && comma.start_offset < to }&.end_offset
    end

    def skip_commented_rows(position, limit)
      while position < limit
        line_end = @bytes.index("\n", position)
        break unless line_end && line_end < limit && @bytes[position..line_end].match?(COMMENTED_ROW)

        position = line_end + 1
      end
      position
    end

    # The whitespace before +offset+ when nothing else is on its line before it.
    def line_lead(offset)
      newline = offset.zero? ? nil : @bytes.rindex("\n", offset - 1)
      line_start = newline ? newline + 1 : 0
      lead = @bytes[line_start...offset]
      lead if lead.match?(/\A[ \t]*\z/)
    end

    def indent
      @elements.each do |element|
        lead = line_lead(element.location.start_offset)
        return lead if lead
      end
      "#{base_indent}  "
    end

    def base_indent
      newline = @bytes.rindex("\n", @array.opening_loc.start_offset)
      @bytes[(newline ? newline + 1 : 0)..][/\A[ \t]*/]
    end
  end
end
