# frozen_string_literal: true

# Boots the test/dummy host app for the engine's integration tests. Fast path
# (seconds) next to the full release gate (build gems -> inline_forms create
# MyApp --example -> rails test); catches controller/view/Turbo regressions
# without an install cycle. See stuff/prompt/test-the-example-app.md for the
# release gate, which remains authoritative.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/autorun"

# In-memory SQLite: define the schema on every boot (maintain_test_schema is
# off; there are no migration files to run).
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :widgets, force: true do |t|
    t.string  :name
    t.text    :notes
    t.date    :released_on
    t.time    :meeting_at
    t.date    :start_month
    t.integer :priority
    t.boolean :active
    t.integer :kind_id
    t.string  :kind_other
    t.integer :rating
    t.string  :manual
    t.string  :accent
    t.timestamps
  end

  create_table :kinds, force: true do |t|
    t.string :name
    t.timestamps
  end

  # PaperTrail (paper_trail 17.x shape).
  create_table :versions, force: true do |t|
    t.string   :item_type, null: false
    t.bigint   :item_id, null: false
    t.string   :event, null: false
    t.string   :whodunnit
    t.text     :object, limit: 1_073_741_823
    t.text     :object_changes, limit: 1_073_741_823
    t.datetime :created_at
  end
  add_index :versions, [ :item_type, :item_id ]
end

class InlineFormsIntegrationTestCase < ActionDispatch::IntegrationTest
  # The inline UI drives every request through a <turbo-frame>; the frame
  # layout (turbo_rails/frame) also spares the dummy the full chrome (header
  # needs current_user, assets, ...).
  def frame_headers(frame_id)
    { "Turbo-Frame" => frame_id, "Accept" => "text/html" }
  end

  setup do
    Widget.delete_all
    Kind.delete_all
    PaperTrail::Version.delete_all
  end
end
