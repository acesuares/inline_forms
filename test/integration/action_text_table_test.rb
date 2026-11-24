# frozen_string_literal: true

require_relative "../integration_test_helper"

# An app may load Action Text (rails/all) without installing it: the class
# is there, the action_text_rich_texts table is not. The versions panel then
# lists the record's own versions instead of failing on the missing table.
class ActionTextTableTest < InlineFormsIntegrationTestCase
  # Stands in for ActionText::RichText in an app without the table: any
  # query on it fails, as it would there.
  module FakeActionText
    class RichText
      def self.table_exists? = false
      def self.where(*) = raise(ActiveRecord::StatementInvalid, "no table action_text_rich_texts")
    end
  end

  def with_action_text_without_table
    raise "the dummy app has no Action Text; this test fakes it" if Object.const_defined?(:ActionText)

    Object.const_set(:ActionText, FakeActionText)
    yield
  ensure
    Object.send(:remove_const, :ActionText) if Object.const_get(:ActionText, false).equal?(FakeActionText)
  end

  test "without Action Text there is no table to ask" do
    refute InlineForms.action_text_table?
  end

  test "Action Text loaded but not installed: the versions are the record's own" do
    widget = Widget.create!(name: "Versioned", notes: "first notes here")
    widget.update!(name: "Versioned twice")

    with_action_text_without_table do
      refute InlineForms.action_text_table?
      entries = ApplicationController.helpers.inline_forms_versions_for(widget)

      assert_equal widget.versions.count, entries.size
      assert entries.all? { |entry| entry[:kind] == :primary }
    end
  end
end
