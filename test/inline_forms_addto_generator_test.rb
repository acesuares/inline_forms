# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "logger"
require "rails"
require "active_record"
require "rails/generators"
require "inline_forms"
require_relative "../lib/generators/inline_forms_addto_generator"

class InlineFormsAddtoGeneratorTest < Minitest::Test
  GENERATOR_SHAPED_MODEL = <<~RUBY
    class Widget < ApplicationRecord

      belongs_to :category

      def inline_forms_attribute_list
        @inline_forms_attribute_list ||= [
          [ :name, :text_field ],
          [ :category, :belongs_to ],
        ]
      end

    end
  RUBY

  INSTALLER_SHAPED_USER = <<~RUBY
    class User < ApplicationRecord

      devise :database_authenticatable
      belongs_to :locale
      has_and_belongs_to_many :roles

      def _presentation
        "\#{name}"
      end

      def inline_forms_attribute_list
        @inline_forms_attribute_list ||= [
          [ :header_user_login, :header ],
          [ :name,              :text_field ],
          [ :email,             :text_field ],
          [ :locale,            :dropdown ],
          [ :password,          :devise_password_field ],
          [ :header_user_roles, :header ],
          [ :roles,             :check_list ],
        ]
      end

    end
  RUBY

  BARE_MODEL = <<~RUBY
    class Bare < ApplicationRecord
    end
  RUBY

  # A model whose list ends with a trailing metadata block (a :header above
  # :info / timestamps rows). New rows must land above the header, not after
  # the info rows.
  METADATA_MODEL = <<~RUBY
    class Profile < ApplicationRecord

      def inline_forms_attribute_list
        @inline_forms_attribute_list ||= [
          [ :name, :text_field ],
          [ :bio, :text_area ],
          [ :header_meta, :header ],
          [ :encrypted_password, :info ],
          [ :created_at, :info ],
          [ :updated_at, :info ],
        ]
      end

    end
  RUBY

  # List closed with `].freeze` and a method defined *after* the list. The old
  # greedy `]\\n end` regex could mismatch here; the bracket-depth scan must not.
  FROZEN_LIST_MODEL = <<~RUBY
    class Gadget < ApplicationRecord

      def inline_forms_attribute_list
        @inline_forms_attribute_list ||= [
          [ :name, :text_field ],
          [ :size, :integer_field ],
        ].freeze
      end

      def _presentation
        "\#{name}"
      end

    end
  RUBY

  def setup
    @destination_root = Dir.mktmpdir("inline_forms_addto_generator_test")
    mkdir_p("app/models")
    mkdir_p("db/migrate")
  end

  def teardown
    FileUtils.remove_entry(@destination_root) if @destination_root && Dir.exist?(@destination_root)
  end

  def test_raises_when_model_file_missing
    stdout, stderr = capture_io do
      run_generator("DoesNotExist", "occupation:string")
    end
    output = "#{stdout}#{stderr}"
    assert_includes(output, "rails g inline_forms DoesNotExist")
    refute(File.exist?(File.join(@destination_root, "app/models/does_not_exist.rb")))
  end

  def test_adds_scalar_column_belongs_to_rich_text_and_image_field_to_existing_model
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    run_generator(
      "Widget",
      "occupation:string",
      "organization:belongs_to",
      "supplier:dropdown",
      "bio:rich_text",
      "avatar:image_field"
    )

    model = read("app/models/widget.rb")
    migration = read_single_addto_migration_for("widgets")

    assert_includes(model, "belongs_to :organization")
    assert_includes(model, "belongs_to :supplier")
    assert_includes(model, "has_rich_text :bio")
    assert_includes(model, "mount_uploader :avatar, AvatarUploader")
    assert_includes(model, '[ :occupation, :text_field ]')
    # :belongs_to is a relation -> no row in inline_forms_attribute_list
    # (matches InlineFormsGenerator semantics). :dropdown is not a relation
    # at lookup time, so it does get a row.
    refute_includes(model, '[ :organization, :belongs_to ]')
    assert_includes(model, '[ :supplier, :dropdown ]')
    assert_includes(model, '[ :avatar, :image_field ]')

    assert_includes(migration, "add_column :widgets, :occupation, :string")
    assert_includes(migration, "add_reference :widgets, :organization, foreign_key: true")
    assert_includes(migration, "add_reference :widgets, :supplier, foreign_key: true")
    assert_includes(migration, "add_column :widgets, :avatar, :string")
    refute_includes(migration, ":bio")
    refute_includes(migration, "create_table")
  end

  def test_header_adds_a_row_but_no_migration_column
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    capture_io { run_generator("Widget", "section:header") }

    model = read("app/models/widget.rb")
    assert_includes(model, "[ :section, :header ]")
    # A header needs no column, so no migration should be written at all.
    refute_addto_migration_for("widgets")
  end

  def test_header_alongside_scalar_migrates_only_the_scalar
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    capture_io { run_generator("Widget", "section:header", "note:string") }

    migration = read_single_addto_migration_for("widgets")
    assert_includes(migration, "add_column :widgets, :note, :string")
    refute_includes(migration, ":section")
  end

  def test_idempotent_rerun_does_not_duplicate_lines
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    run_generator("Widget", "occupation:string", "organization:belongs_to")
    sleep 1 # unique migration timestamp on second run
    run_generator("Widget", "occupation:string", "organization:belongs_to")

    model = read("app/models/widget.rb")

    assert_equal(1, model.scan("belongs_to :organization").size)
    assert_equal(1, model.scan('[ :occupation, :text_field ]').size)
  end

  def test_appends_row_to_installer_shaped_user_attribute_list
    write_model("user.rb", INSTALLER_SHAPED_USER)

    run_generator("User", "occupation:string", "birthdate:date")

    model = read("app/models/user.rb")

    assert_includes(model, '[ :occupation, :text_field ]')
    assert_includes(model, '[ :birthdate, :date_select ]')
    refute_match(/\]\s*\n\s*\[\s*:occupation/, model)

    user_array_section = model[/@inline_forms_attribute_list \|\|=\s*\[(.|\n)*?\n\s*\]/]
    assert(user_array_section, "could not locate @inline_forms_attribute_list array")
    assert_match(/\[ :roles,.*\].*?\[ :occupation\b/m, user_array_section)
  end

  def test_bare_model_gets_fresh_attribute_list_method
    write_model("bare.rb", BARE_MODEL)

    out, _err = capture_io do
      run_generator("Bare", "occupation:string")
    end

    model = read("app/models/bare.rb")

    assert_includes(out, "no inline_forms_attribute_list found")
    assert_includes(model, "def inline_forms_attribute_list")
    assert_includes(model, '[ :occupation, :text_field ]')
  end

  def test_unknown_type_raises_thor_error_by_default
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    stdout, stderr = capture_io do
      run_generator("Widget", "payload:not_a_real_type")
    end
    output = "#{stdout}#{stderr}"
    assert_includes(output, "Unknown field type(s): payload:not_a_real_type")
    assert_includes(output, "--allow-unknown")

    refute_addto_migration_for("widgets")
  end

  def test_allow_unknown_keeps_legacy_commented_output
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    run_generator("Widget", "payload:not_a_real_type", "--allow-unknown")

    model = read("app/models/widget.rb")
    migration = read_single_addto_migration_for("widgets")

    assert_includes(model, '[ :payload, :unknown ]')
    assert_includes(migration, "#    add_column :widgets, :payload, :unknown")
  end

  def test_install_time_only_names_are_rejected
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    %w[_no_model _no_migration _id _enabled].each do |forbidden|
      stdout, stderr = capture_io do
        run_generator("Widget", "#{forbidden}:yes")
      end
      output = "#{stdout}#{stderr}"
      assert_includes(output, forbidden, "expected error to mention #{forbidden}")
      assert_includes(output, "install-time only")
    end
  end

  def test_skips_replace_only_names_without_replace_flag
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    out, _err = capture_io do
      run_generator("Widget", "_list_order:title")
    end

    assert_includes(out, "_list_order:title")
    assert_includes(out, "skipped")
    model = read("app/models/widget.rb")
    refute_includes(model, "scope :inline_forms_list, -> { order(:title, :id) }")
  end

  def test_replace_flag_rewrites_list_order_scope
    initial = GENERATOR_SHAPED_MODEL.sub(
      /class Widget < ApplicationRecord\n/,
      "class Widget < ApplicationRecord\n\n  scope :inline_forms_list, -> { order(:name, :id) }\n  def <=>(other)\n    self.name <=> other.name\n  end\n"
    )
    write_model("widget.rb", initial)

    run_generator("Widget", "_list_order:title", "--replace")

    model = read("app/models/widget.rb")
    assert_includes(model, "scope :inline_forms_list, -> { order(:title, :id) }")
    refute_includes(model, "order(:name, :id)")
    assert_includes(model, "self.title <=> other.title")
    refute_includes(model, "self.name <=> other.name")
  end

  def test_smart_placement_lands_above_trailing_metadata_block
    write_model("profile.rb", METADATA_MODEL)

    capture_io { run_generator("Profile", "occupation:string") }

    model = read("app/models/profile.rb")
    assert_includes(model, "[ :occupation, :text_field ]")
    # Above the metadata header, and therefore above every :info row.
    assert(model.index("[ :occupation") < model.index("[ :header_meta"),
           "occupation should be inserted above the metadata header")
    assert(model.index("[ :bio") < model.index("[ :occupation"),
           "occupation should stay below the existing content rows")
  end

  def test_frozen_list_and_trailing_method_do_not_break_insertion
    write_model("gadget.rb", FROZEN_LIST_MODEL)

    capture_io { run_generator("Gadget", "color:string") }

    model = read("app/models/gadget.rb")
    assert_includes(model, "[ :color, :text_field ]")
    # Still a single, valid, frozen list; the trailing method is untouched.
    assert_equal(1, model.scan("].freeze").size)
    assert_includes(model, "def _presentation")
    assert(model.index("[ :size") < model.index("[ :color"),
           "color should be appended after the last existing row")
    assert(model.index("[ :color") < model.index("].freeze"),
           "color should be inside the frozen array")
    refute_includes(model, "no inline_forms_attribute_list found")
  end

  def test_after_option_places_row_after_named_attribute
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    capture_io { run_generator("Widget", "occupation:string", "--after=name") }

    model = read("app/models/widget.rb")
    assert(model.index("[ :name") < model.index("[ :occupation"))
    assert(model.index("[ :occupation") < model.index("[ :category"))
  end

  def test_before_option_places_row_before_named_attribute
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    capture_io { run_generator("Widget", "occupation:string", "--before=category") }

    model = read("app/models/widget.rb")
    assert(model.index("[ :occupation") < model.index("[ :category"))
  end

  def test_missing_anchor_warns_and_falls_back_to_default
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    out, _err = capture_io do
      run_generator("Widget", "occupation:string", "--after=nope")
    end

    assert_includes(out, "--after nope not found")
    model = read("app/models/widget.rb")
    assert_includes(model, "[ :occupation, :text_field ]")
  end

  def test_value_bearing_element_gets_placeholder_hash_and_warns
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    out, _err = capture_io do
      run_generator("Widget", "status:dropdown_with_values")
    end

    model = read("app/models/widget.rb")
    assert_includes(model, "[ :status, :dropdown_with_values, { 1 => 'one', 2 => 'two' } ]")
    assert_includes(out, "values hash")
  end

  def test_back_to_back_runs_produce_distinct_migration_filenames
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    # No sleep between runs: unique_time_stamp must still disambiguate.
    capture_io { run_generator("Widget", "alpha:string") }
    capture_io { run_generator("Widget", "beta:string") }

    files = Dir.glob(File.join(@destination_root, "db/migrate/*_inline_forms_add_to_widgets_*.rb"))
    assert_equal(2, files.size, "expected two distinct addto migrations, got #{files.inspect}")
    prefixes = files.map { |f| File.basename(f)[/\A(\d{14})/, 1] }
    assert_equal(prefixes.uniq.size, prefixes.size, "migration timestamps collided: #{prefixes.inspect}")
  end

  def test_generated_migration_applies_cleanly_to_sqlite
    write_model("widget.rb", GENERATOR_SHAPED_MODEL)

    capture_io { run_generator("Widget", "occupation:string", "organization:belongs_to") }

    migration_file = Dir.glob(
      File.join(@destination_root, "db/migrate/*_inline_forms_add_to_widgets_*.rb")
    ).first
    refute_nil(migration_file, "expected an addto migration to be generated")

    conn = apply_migration_to_memory_sqlite(migration_file, tables: %i[organizations widgets])

    assert(conn.column_exists?(:widgets, :occupation), "occupation column should exist after migrate")
    assert(conn.column_exists?(:widgets, :organization_id), "organization_id column should exist after migrate")
  ensure
    teardown_sqlite
  end

  private

  def run_generator(*args)
    InlineForms::InlineFormsAddtoGenerator.start(args, destination_root: @destination_root)
  end

  # Applies a generated migration file against a fresh in-memory sqlite DB on a
  # dedicated connection (ScratchMigrationBase), pre-creating the referenced
  # tables. Proves the emitted migration DSL is syntactically and semantically
  # valid without a full Rails app — and without disturbing ActiveRecord::Base's
  # connection (the engine integration tests share this process). Returns the
  # scratch connection for assertions.
  def apply_migration_to_memory_sqlite(path, tables:)
    scratch_migration_base.establish_connection(adapter: "sqlite3", database: ":memory:")
    conn = scratch_migration_base.connection
    ActiveRecord::Migration.verbose = false
    tables.each do |t|
      conn.create_table(t, force: true) { |tbl| tbl.string :name }
    end

    src = File.read(path)
    klass_name = src[/class\s+(\w+)\s*</, 1]
    Object.send(:remove_const, klass_name.to_sym) if Object.const_defined?(klass_name.to_sym)
    Object.class_eval(src)
    klass = Object.const_get(klass_name)
    @sqlite_migration_const = klass_name
    # exec_migration(conn, dir) runs the migration against `conn` specifically,
    # unlike migrate(:up) which uses ActiveRecord::Base.connection.
    ActiveRecord::Migration.suppress_messages { klass.new.exec_migration(conn, :up) }
    conn
  end

  def teardown_sqlite
    if @sqlite_migration_const && Object.const_defined?(@sqlite_migration_const.to_sym)
      Object.send(:remove_const, @sqlite_migration_const.to_sym)
    end
    @sqlite_migration_const = nil
    @@scratch_migration_base&.remove_connection
  rescue StandardError
    nil
  end

  # A dedicated abstract ActiveRecord::Base subclass whose connection is the
  # scratch in-memory sqlite DB. Created lazily at *runtime* (not file-load
  # time): subclassing ActiveRecord::Base before the dummy app boots trips the
  # railtie into resolving the wrong Rails env. Never touches Base's own
  # connection, so the engine integration tests sharing this process keep the
  # dummy app's in-memory schema.
  @@scratch_migration_base = nil

  def scratch_migration_base
    @@scratch_migration_base ||= begin
      unless Object.const_defined?(:ScratchAddtoMigrationBase)
        Object.const_set(:ScratchAddtoMigrationBase,
                         Class.new(ActiveRecord::Base) { self.abstract_class = true })
      end
      Object.const_get(:ScratchAddtoMigrationBase)
    end
  end

  def write_model(file, content)
    File.write(File.join(@destination_root, "app/models", file), content)
  end

  def read(relative_path)
    File.read(File.join(@destination_root, relative_path))
  end

  def mkdir_p(relative_path)
    FileUtils.mkdir_p(File.join(@destination_root, relative_path))
  end

  def read_single_addto_migration_for(table_name)
    files = Dir.glob(File.join(@destination_root, "db/migrate/*_inline_forms_add_to_#{table_name}_*.rb"))
    assert_equal(1, files.size, "Expected one addto migration for #{table_name}, got #{files.inspect}")
    File.read(files.first)
  end

  def refute_addto_migration_for(table_name)
    files = Dir.glob(File.join(@destination_root, "db/migrate/*_inline_forms_add_to_#{table_name}_*.rb"))
    assert_equal([], files, "Expected no addto migration for #{table_name}")
  end
end
