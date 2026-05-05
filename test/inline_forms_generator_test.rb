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
    application_controller = read("app/controllers/application_controller.rb")
    migration = read_single_migration_for("things")

    assert_includes(model, "class Thing < ApplicationRecord")
    assert_includes(model, "belongs_to :category")
    assert_includes(model, "has_many :photos")
    assert_includes(model, "[ :name , \"name\", :text_field ]")
    assert_includes(model, "[ :category , \"category\", :dropdown ]")

    assert_includes(controller, "class ThingsController < InlineFormsController")
    assert_includes(controller, "set_tab :thing")

    assert_includes(routes, "resources :things do")
    assert_includes(routes, "post 'revert', :on => :member")
    assert_includes(routes, "get 'list_versions', :on => :member")

    assert_includes(application_controller, "MODEL_TABS = %w(things ")

    assert_includes(migration, "class InlineFormsCreateThings < ActiveRecord::Migration[7.0]")
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

    assert_includes(model, "#     [ :payload , \"payload\", :unknown ]")
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

  private

  def build_destination_skeleton!
    mkdir_p("config")
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
          ActionView::CompiledTemplates::MODEL_TABS = %w()
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
