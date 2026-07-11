# -*- encoding : utf-8 -*-

require "shellwords"

module InlineForms
  # Skeleton of the "apply" step of the staging pipeline: turn an approved
  # SchemaIntent into the ordered shell commands a developer would run by hand
  # (generate the migration + model edit, migrate, test, commit, restart). This
  # is the rare, expensive, deliberate step — see the staging doc.
  #
  # The engine does NOT execute these itself by default: which host runs them
  # (a rake task on a single-server box, or a CI job after a PR on a clustered
  # deploy) is an app decision. #commands returns the plan for inspection;
  # #run! executes it via an injectable runner (defaults to Kernel#system) and
  # stops at the first failure, so an app/rake task can opt in.
  class SchemaApply
    STEPS = %i[generate migrate].freeze

    attr_reader :intent

    def initialize(intent, runner: nil)
      @intent = intent
      @runner = runner || ->(cmd) { system(*cmd) }
    end

    # `rails g inline_forms_addto <Model> <attr:fe> [--after=..]`.
    def generator_command
      %w[bundle exec rails g inline_forms_addto] + intent.generator_args
    end

    def migrate_command
      %w[bundle exec rails db:migrate]
    end

    # Ordered plan (each value is an argv array).
    def commands
      { generate: generator_command, migrate: migrate_command }
    end

    # Human-readable plan (what an app would show before the user confirms).
    def preview_plan
      STEPS.map { |step| "#{step}: #{Shellwords.join(commands.fetch(step))}" }
    end

    # Execute generate -> migrate, stopping at the first failure. Returns the
    # step that failed, or nil on success. NOT run in tests (would shell out);
    # an app/rake task calls this after approval + a git-clean check.
    def run!
      STEPS.each do |step|
        ok = @runner.call(commands.fetch(step))
        return step unless ok
      end
      nil
    end
  end
end
