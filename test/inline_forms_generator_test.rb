# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "logger"
require "rails"
require "rails/generators"
require "inline_forms"
require_relative "../lib/generators/inline_forms_generator"

class InlineFormsGeneratorTest < Minitest::Test
  def setup
    @destination_root = Dir.mktmpdir("inline_forms_generator_test")
    build_destination_skeleton!
  end

  def teardown
    FileUtils.remove_entry(@destination_root) if @destination_root && Dir.exist?(@destination_root)
  end

  def test_generates_model_controller_route_migration_and_tab_injection
    run_generator(
      "Thing",
      "name:string",
      "category:dropdown",
      "photos:has_many",
      "_enabled:yes",
      "_presentation:\\#{name}"
    )

    model = read("app/models/thing.rb")
    controller = read("app/controllers/things_controller.rb")
    routes = read("config/routes.rb")
    inline_forms_initializer = read("config/initializers/inline_forms.rb")
    migration = read_single_migration_for("things")

    assert_includes(model, "class Thing < ApplicationRecord")
    refute_includes(model, "has_paper_trail")
    refute_includes(model, "attr_reader :per_page")
    refute_includes(model, 'def self.not_accessible_through_html?')
    refute_includes(model, "def self.order_by_clause")
    refute_includes(model, "scope :inline_forms_list")
    refute_includes(model, "scope :inline_forms_search")
    assert_includes(model, "belongs_to :category")
    assert_includes(model, "has_many :photos")
    assert_includes(model, "[ :name, :text_field ]")
    assert_includes(model, "[ :category, :dropdown ]")

    assert_includes(controller, "class ThingsController < InlineFormsController")
    assert_includes(controller, "set_tab :thing")

    assert_includes(routes, "resources :things do")
    assert_includes(routes, "post 'revert', :on => :member")
    assert_includes(routes, "get 'list_versions', :on => :member")

    assert_includes(inline_forms_initializer, "MODEL_TABS = %w(things ")

    assert_includes(migration, "class InlineFormsCreateThings < ActiveRecord::Migration[8.1]")
    assert_includes(migration, "create_table :things do |t|")
    assert_includes(migration, "t.string :name")
    assert_includes(migration, "t.belongs_to :category")
    refute_includes(migration, "photos")
  end

  def test_skips_model_controller_and_routes_when_no_model_flag_is_present
    run_generator("AuditLog", "message:string", "_no_model:yes")

    refute_exist("app/models/audit_log.rb")
    refute_exist("app/controllers/audit_logs_controller.rb")

    routes = read("config/routes.rb")
    refute_includes(routes, "resources :audit_logs")
  end

  def test_fails_fast_for_unknown_types_by_default
    stdout, stderr = capture_io do
      run_generator("Mystery", "payload:not_a_real_type", "--no-allow-unknown")
    end
    output = "#{stdout}#{stderr}"

    assert_includes(output, "Unknown field type(s): payload:not_a_real_type")
    assert_includes(output, "--allow-unknown")
    refute_exist("app/models/mystery.rb")
    assert_equal([], Dir.glob(File.join(@destination_root, "db/migrate/*_inline_forms_create_mysteries.rb")))
  end

  def test_allow_unknown_keeps_legacy_commented_output
    run_generator("Mystery", "payload:not_a_real_type", "--allow-unknown")

    model = read("app/models/mystery.rb")
    migration = read_single_migration_for("mysteries")

    assert_includes(model, "#     [ :payload, :unknown ]")
    assert_includes(migration, "#     t.unknown :payload")
  end

  def test_rich_text_adds_has_rich_text_without_migration_column
    run_generator("Article", "title:string", "content:rich_text")

    model = read("app/models/article.rb")
    migration = read_single_migration_for("articles")

    assert_includes(model, "has_rich_text :content")
    refute_includes(migration, "t.no_migration :content")
    refute_includes(migration, "t.text :content")
  end

  def test_not_accessible_and_list_order_emits_scope_and_spaceship
    run_generator(
      "Photo",
      "name:string",
      "album:belongs_to",
      "_presentation:\\#{name}",
      "_list_order:caption"
    )

    model = read("app/models/photo.rb")
    assert_includes(model, "def self.not_accessible_through_html?\n    true")
    assert_includes(model, "scope :inline_forms_list, -> { order(:caption, :id) }")
    assert_includes(model, "def <=>(other)")
    assert_includes(model, "self.caption <=> other.caption")
    refute_includes(model, "def self.order_by_clause")
    refute_includes(model, "has_paper_trail")
  end

  def test_legacy_order_alias_still_emits_scope_with_deprecation_warning
    stdout, stderr = capture_io do
      run_generator(
        "Photo",
        "name:string",
        "_presentation:\\#{name}",
        "_order:caption"
      )
    end

    output = "#{stdout}#{stderr}"
    assert_includes(output, "_order:caption is deprecated")
    assert_includes(output, "_list_order:caption")

    model = read("app/models/photo.rb")
    assert_includes(model, "scope :inline_forms_list, -> { order(:caption, :id) }")
    refute_includes(model, "def self.order_by_clause")
  end

  def test_list_search_emits_search_scope
    run_generator(
      "Apartment",
      "name:string",
      "_enabled:yes",
      "_list_order:name",
      "_list_search:name",
      "_presentation:\\#{name}"
    )

    model = read("app/models/apartment.rb")
    assert_includes(model, "scope :inline_forms_list, -> { order(:name, :id) }")
    assert_includes(model, "scope :inline_forms_search, ->(q) { where(\"name LIKE ?\", \"%\#{q}%\") }")
    migration = read_single_migration_for("apartments")
    refute_includes(migration, "_list_order")
    refute_includes(migration, "_list_search")
  end

  def test_plain_text_generates_text_column_and_plain_text_form_element
    run_generator("Note", "title:string", "description:plain_text")

    model = read("app/models/note.rb")
    migration = read_single_migration_for("notes")

    assert_includes(model, "[ :description, :plain_text ]")
    assert_includes(migration, "t.text :description")
  end

  private

  def build_destination_skeleton!
    mkdir_p("config")
    mkdir_p("config/initializers")
    mkdir_p("app/controllers")
    mkdir_p("app/models")
    mkdir_p("db/migrate")
    mkdir_p("test/unit")

    write(
      "config/routes.rb",
      <<~RUBY
        Rails.application.routes.draw do
        end
      RUBY
    )

    write(
      "app/controllers/application_controller.rb",
      <<~RUBY
        class ApplicationController < ActionController::Base
        end
      RUBY
    )

    # Matches the file the installer writes; the generator's `add_tab` step
    # injects `<plural_route> ` tokens after the `MODEL_TABS = %w(` marker.
    write(
      "config/initializers/inline_forms.rb",
      <<~RUBY
        Rails.application.reloader.to_prepare do
          MODEL_TABS = %w()
        end
      RUBY
    )
  end

  def run_generator(*args)
    InlineForms::InlineFormsGenerator.start(args, destination_root: @destination_root)
  end

  def read(relative_path)
    File.read(File.join(@destination_root, relative_path))
  end

  def read_single_migration_for(table_name)
    migration_files = Dir.glob(File.join(@destination_root, "db/migrate/*_inline_forms_create_#{table_name}.rb"))
    assert_equal(1, migration_files.size, "Expected one migration for #{table_name}, got #{migration_files.inspect}")
    File.read(migration_files.first)
  end

  def refute_exist(relative_path)
    refute(File.exist?(File.join(@destination_root, relative_path)), "Expected #{relative_path} to not exist")
  end

  def mkdir_p(relative_path)
    FileUtils.mkdir_p(File.join(@destination_root, relative_path))
  end

  def write(relative_path, content)
    File.write(File.join(@destination_root, relative_path), content)
  end
end
