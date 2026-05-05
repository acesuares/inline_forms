# frozen_string_literal: true

require "test_helper"

# Regression: PaperTrail (>= 13) deserializes `versions.object_changes` via
# `YAML.safe_load`, using `ActiveRecord.yaml_column_permitted_classes` as the
# allow-list. Rails 7's default is `[Symbol]`, so any update that touches
# `updated_at` (an `ActiveSupport::TimeWithZone`) raises `Psych::DisallowedClass`
# inside `version.changeset`, and PaperTrail rescues that into `{}`. The
# inline_forms versions list then renders every changeset as `empty`.
#
# The installer ships `config/initializers/paper_trail_yaml_safe_load.rb`,
# which extends the allow-list. This test fails if that initializer is
# missing or insufficient.
class ExampleAppPaperTrailChangesetTest < ActiveSupport::TestCase
  test "version.changeset round-trips a normal update" do
    PaperTrail.request.whodunnit = "test"

    apartment = Apartment.create!(name: "Original", title: "Old Title")
    apartment.update!(name: "Renamed", title: "New Title")

    version = apartment.versions.last
    assert_equal "update", version.event,
      "expected an update version to be recorded by paper_trail"

    changeset = version.changeset
    assert_kind_of Hash, changeset
    refute_empty changeset,
      "version.changeset is empty; PaperTrail's YAML.safe_load probably hit a " \
      "DisallowedClass and returned {}. Check " \
      "config/initializers/paper_trail_yaml_safe_load.rb and the Rails " \
      "ActiveRecord.yaml_column_permitted_classes setting."

    assert_equal ["Original", "Renamed"], changeset["name"]
    assert_equal ["Old Title", "New Title"], changeset["title"]
  end

  # `has_rich_text :description` lives in the `action_text_rich_texts` table,
  # so `has_paper_trail` on Apartment cannot see body edits. The installer adds
  # `config/initializers/rich_text_paper_trail.rb` (which declares
  # `has_paper_trail` on `ActionText::RichText`), and `inline_forms_versions_for`
  # merges rich-text versions into the parent's history. This test fails if
  # either piece regresses.
  test "rich_text edits surface in the merged versions list for the parent" do
    PaperTrail.request.whodunnit = "test"

    apartment = Apartment.create!(name: "RT", title: "RT", description: "v1 body")
    apartment.update!(description: "v2 body")

    rich_text = ActionText::RichText.find_by!(
      record_type: Apartment.name, record_id: apartment.id, name: "description"
    )
    assert rich_text.respond_to?(:versions),
      "ActionText::RichText is missing has_paper_trail; check " \
      "config/initializers/rich_text_paper_trail.rb"
    refute_empty rich_text.versions,
      "no PaperTrail versions on ActionText::RichText; the on_load hook " \
      "in config/initializers/rich_text_paper_trail.rb did not fire or " \
      "has_paper_trail was not applied"

    helper = Class.new { include InlineFormsHelper }.new
    entries = helper.inline_forms_versions_for(apartment)

    rich_text_entries = entries.select { |e| e[:kind] == :rich_text }
    refute_empty rich_text_entries,
      "inline_forms_versions_for did not return any rich_text entries"

    body_changes = rich_text_entries
      .map { |e| e[:version].changeset }
      .select { |cs| cs && cs["body"].is_a?(Array) }
      .map { |cs| cs["body"] }

    refute_empty body_changes,
      "no body changesets recorded for ActionText::RichText"
    assert body_changes.any? { |old, new_| old.to_s.include?("v1 body") && new_.to_s.include?("v2 body") },
      "expected an entry whose body change moves from 'v1 body' to 'v2 body'; got #{body_changes.inspect}"
  end
end
