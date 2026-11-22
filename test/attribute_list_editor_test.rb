# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/generators/inline_forms_attribute_list_editor"

class AttributeListEditorTest < Minitest::Test
  ROW = "[ :color, :text_field ]"

  def test_before_a_splat
    assert_inserted([ "[ :name, :text_field ],", "*EXTRA" ],
                    [ "[ :name, :text_field ],", "#{ROW},", "*EXTRA" ])
  end

  def test_before_a_conditional_row
    assert_inserted([ "[ :name, :text_field ],", "([ :secret, :text_field ] if admin?)" ],
                    [ "[ :name, :text_field ],", "#{ROW},", "([ :secret, :text_field ] if admin?)" ])
  end

  def test_entries_above_the_metadata_are_not_touched
    [ "([ :secret, :text_field ] if admin?),", "*(admin? ? [ [ :x, :text_field ] ] : []),",
      "[ :a, :text_field ].freeze,", "[ :s, :radio_button, { 1 => 'a]', 2 => '[b' } ], # x ], y" ].each do |entry|
      assert_inserted([ entry, "[ :created_at, :info ]" ], [ entry, "#{ROW},", "[ :created_at, :info ]" ])
    end
  end

  def test_two_rows_on_one_line
    assert_inserted([ "[ :a, :text_field ], [ :b, :text_field ]" ],
                    [ "[ :a, :text_field ], [ :b, :text_field ],", ROW ])
    assert_inserted([ "[ :a, :text_field ], [ :b, :text_field ]" ],
                    [ "[ :a, :text_field ], #{ROW}, [ :b, :text_field ]" ], after: "a")
    assert_inserted([ "[ :a, :text_field ], [ :b, :text_field ]" ],
                    [ "[ :a, :text_field ], #{ROW}, [ :b, :text_field ]" ], before: "b")
  end

  def test_last_row_with_a_method_call
    assert_inserted([ "[ :a, :text_field ].freeze" ], [ "[ :a, :text_field ].freeze,", ROW ])
    assert_inserted([ "[ :a, :text_field ].freeze," ], [ "[ :a, :text_field ].freeze,", ROW ])
  end

  def test_brackets_and_hashes_in_labels_and_comments
    assert_inserted([ "[ :s, :radio_button, { 1 => 'a]', 2 => '[b #1' } ]" ],
                    [ "[ :s, :radio_button, { 1 => 'a]', 2 => '[b #1' } ],", ROW ])
    assert_inserted([ "[ :s, :text_field ] # see ], [x, y" ], [ "[ :s, :text_field ], # see ], [x, y", ROW ])
  end

  def test_row_over_several_lines
    rows = [ "[ :name, :text_field ],", "[ :status, :radio_button,", "  { 1 => 'a',", "    2 => 'b' } ]" ]
    assert_inserted(rows, rows[0..2] + [ "    2 => 'b' } ],", ROW ])
    assert_inserted(rows, [ rows[0], "#{ROW},", *rows[1..] ], before: "status")
    assert_inserted([ *rows[0..2], "    2 => 'b' } ], # last", "[ :created_at, :info ]," ],
                    [ *rows[0..2], "    2 => 'b' } ], # last", "#{ROW},", "[ :created_at, :info ]," ])
  end

  def test_below_commented_out_rows
    assert_inserted([ "[ :name, :text_field ]", "# [ :old, :text_field ],", "# a remark" ],
                    [ "[ :name, :text_field ],", "# [ :old, :text_field ],", ROW, "# a remark" ])
  end

  def test_header_above_the_metadata
    assert_inserted([ "[ :a, :text_field ],", "[ :meta, :header ],", "[ :created_at, :info ]" ],
                    [ "[ :a, :text_field ],", "#{ROW},", "[ :meta, :header ],", "[ :created_at, :info ]" ])
  end

  def test_single_line_and_empty_lists
    assert_equal(list("[ [ :a, :text_field ], [ :b, :text_field ], #{ROW} ]"),
                 insert(list("[ [ :a, :text_field ], [ :b, :text_field ] ]")))
    assert_equal(list("[ [ :a, :text_field ], #{ROW} ]"), insert(list("[ [ :a, :text_field ] ]")))
    assert_equal(list("[ [ :a, :text_field ], #{ROW} ]"), insert(list("[ [ :a, :text_field ], ]")))
    assert_equal(list("[\n      #{ROW}\n    ]"), insert(list("[]")))
    assert_equal(list("[\n      #{ROW}\n    ]"), insert(list("[\n    ]")))
  end

  def test_list_with_something_behind_it
    [ ".freeze", " + EXTRA", ".map { |row| row }" ].each do |behind|
      assert_equal(list("[\n      [ :a, :text_field ],\n      #{ROW}\n    ]#{behind}"),
                   insert(list("[\n      [ :a, :text_field ]\n    ]#{behind}")))
    end
  end

  def test_text_that_is_not_ascii
    assert_inserted([ "[ :s, :radio_button, { 1 => 'één' } ], # ünï", "[ :b, :text_field ]" ],
                    [ "[ :s, :radio_button, { 1 => 'één' } ], # ünï", "[ :b, :text_field ],", ROW ])
  end

  def test_no_list
    refute(InlineForms::AttributeListEditor.new("class Widget\nend\n").list?)
    refute(InlineForms::AttributeListEditor.new("class Widget\n  def l = @inline_forms_attribute_list ||= build\nend\n").list?)
  end

  def test_refuses_a_file_with_a_syntax_error
    assert_raises(InlineForms::AttributeListEditor::Unplaceable) { InlineForms::AttributeListEditor.new("class Widget\n  [\nend\n") }
  end

  def test_refuses_what_would_not_become_one_element
    editor = InlineForms::AttributeListEditor.new(list("[\n      [ :a, :text_field ]\n    ]"))
    assert_raises(InlineForms::AttributeListEditor::Unplaceable) { editor.insert("[ :x, :text_field ], [ :y, :text_field ]") }
    assert_raises(InlineForms::AttributeListEditor::Unplaceable) { editor.insert("[ :x, ") }
  end

  private

  def assert_inserted(rows, expected, **anchor)
    result = insert(list_of(rows), **anchor)
    assert_equal(list_of(expected), result)
    assert(RubyVM::InstructionSequence.compile(result))
  end

  def insert(source, **anchor)
    InlineForms::AttributeListEditor.new(source).insert(ROW, **anchor).first
  end

  def list_of(rows)
    list("[\n#{rows.map { |row| "      #{row}\n" }.join}    ]")
  end

  def list(literal)
    "class Widget\n  def inline_forms_attribute_list\n    @inline_forms_attribute_list ||= #{literal}\n  end\nend\n"
  end
end
