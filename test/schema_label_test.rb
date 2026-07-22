# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class SchemaLabelTest < Minitest::Test
  # Minimal stand-in for an AR model name (avoids booting ActiveRecord).
  ModelName = Struct.new(:i18n_key)
  class FakeModel
    def self.model_name = ModelName.new(:apartment)
  end

  def setup
    @root = Dir.mktmpdir("schema_label_test")
    FileUtils.mkdir_p(File.join(@root, "config", "locales"))
  end

  def teardown
    FileUtils.remove_entry(@root) if @root && Dir.exist?(@root)
  end

  def read_yaml(path)
    YAML.safe_load(File.read(path))
  end

  def test_writes_label_under_the_human_attribute_name_key
    path = InlineForms::SchemaLabel.write(
      destination_root: @root, model_class: FakeModel,
      attribute: :internal_note, label: "Internal note", locale: :en
    )
    assert_equal File.join(@root, "config/locales/inline_forms_labels.en.yml"), path
    doc = read_yaml(path)
    assert_equal "Internal note",
                 doc.dig("en", "activerecord", "attributes", "apartment", "internal_note")
  end

  def test_merges_without_clobbering_existing_labels
    InlineForms::SchemaLabel.write(destination_root: @root, model_class: FakeModel,
                                   attribute: :first_field, label: "First", locale: :en)
    InlineForms::SchemaLabel.write(destination_root: @root, model_class: FakeModel,
                                   attribute: :second_field, label: "Second", locale: :en)

    attrs = read_yaml(InlineForms::SchemaLabel.file_path(@root, :en))
             .dig("en", "activerecord", "attributes", "apartment")
    assert_equal "First", attrs["first_field"]
    assert_equal "Second", attrs["second_field"]
  end

  def test_separate_file_per_locale
    InlineForms::SchemaLabel.write(destination_root: @root, model_class: FakeModel,
                                   attribute: :note, label: "Note", locale: :en)
    InlineForms::SchemaLabel.write(destination_root: @root, model_class: FakeModel,
                                   attribute: :note, label: "Notitie", locale: :nl)

    assert_equal "Note", read_yaml(InlineForms::SchemaLabel.file_path(@root, :en))
                          .dig("en", "activerecord", "attributes", "apartment", "note")
    assert_equal "Notitie", read_yaml(InlineForms::SchemaLabel.file_path(@root, :nl))
                            .dig("nl", "activerecord", "attributes", "apartment", "note")
  end
end
