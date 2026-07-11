# frozen_string_literal: true

require_relative "test_helper"

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

  def test_run_bang_stops_at_first_failure
    calls = []
    runner = ->(cmd) { calls << cmd; false } # generate fails
    result = InlineForms::SchemaApply.new(intent, runner: runner).run!
    assert_equal :generate, result
    assert_equal 1, calls.size, "must not run migrate after generate failed"
  end
end
