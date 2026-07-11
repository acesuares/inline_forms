# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class SchemaApplyTest < Minitest::Test
  def intent(**overrides)
    InlineForms::SchemaIntent.new(
      **{ model_name: "Apartment", attribute: :internal_note, form_element: :text_field }.merge(overrides)
    )
  end

  def test_generator_command
    apply = InlineForms::SchemaApply.new(intent(after: :name))
    assert_equal(
      %w[bundle exec rails g inline_forms_addto Apartment internal_note:text_field --after=name],
      apply.generator_command
    )
  end

  def test_commands_are_ordered_generate_then_migrate
    apply = InlineForms::SchemaApply.new(intent)
    assert_equal %i[generate migrate], apply.commands.keys
    assert_equal %w[bundle exec rails db:migrate], apply.commands[:migrate]
  end

  def test_preview_plan_is_human_readable
    plan = InlineForms::SchemaApply.new(intent).preview_plan
    assert_equal 2, plan.size
    assert_match(/\Agenerate: bundle exec rails g inline_forms_addto Apartment/, plan.first)
  end

  def test_run_bang_executes_in_order_with_injected_runner
    calls = []
    runner = ->(cmd) { calls << cmd; true }
    result = InlineForms::SchemaApply.new(intent, runner: runner).run!
    assert_nil result, "expected success (nil)"
    assert_equal 2, calls.size
    assert_equal %w[bundle exec rails g inline_forms_addto Apartment internal_note:text_field], calls.first
    assert_equal %w[bundle exec rails db:migrate], calls.last
  end

  def test_generate_returns_only_a_newly_created_migration
    Dir.mktmpdir("schema_apply_generate") do |root|
      migrate_dir = File.join(root, "db", "migrate")
      FileUtils.mkdir_p(migrate_dir)
      # A pre-existing addto migration must NOT be reported when this run
      # creates nothing (the :header case).
      FileUtils.touch(File.join(migrate_dir, "20200101000000_inline_forms_add_to_widgets_old.rb"))

      header_executor = ->(_args, _root) { } # header: no migration created
      result = InlineForms::SchemaApply.new(intent(form_element: :header))
                                       .generate!(destination_root: root, executor: header_executor)
      assert_nil result, "header apply must report no migration, not a stale one"

      # A run that creates a migration reports that one.
      creating = lambda do |_args, _root|
        FileUtils.touch(File.join(migrate_dir, "20260101000000_inline_forms_add_to_widgets_note.rb"))
      end
      created = InlineForms::SchemaApply.new(intent).generate!(destination_root: root, executor: creating)
      assert_equal "20260101000000_inline_forms_add_to_widgets_note.rb", File.basename(created)
    end
  end

  def test_run_bang_stops_at_first_failure
    calls = []
    runner = ->(cmd) { calls << cmd; false } # generate fails
    result = InlineForms::SchemaApply.new(intent, runner: runner).run!
    assert_equal :generate, result
    assert_equal 1, calls.size, "must not run migrate after generate failed"
  end
end
