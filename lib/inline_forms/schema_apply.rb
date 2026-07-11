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

    # In-process generate-only executor used by the schema GUI: runs the addto
    # generator against the app's tree (edits the model, writes the migration
    # file) but never migrates. Overridable so tests can record the args
    # instead of mutating the working tree.
    DEFAULT_GENERATE_EXECUTOR = lambda do |args, destination_root|
      require "generators/inline_forms_addto_generator"
      InlineFormsAddtoGenerator.start(args, destination_root: destination_root)
    end

    attr_reader :intent

    def initialize(intent, runner: nil)
      @intent = intent
      @runner = runner || ->(cmd) { system(*cmd) }
    end

    # Run the addto generator in-process (model edit + migration file) WITHOUT
    # running db:migrate. Returns the path of the migration it created (or nil
    # when the executor did not create one, e.g. a recording test executor).
    # The caller (GUI) then tells the user to run `rails db:migrate` + restart;
    # the pending-migration gate covers the interim.
    def generate!(destination_root:, executor: DEFAULT_GENERATE_EXECUTOR)
      before = addto_migrations(destination_root)
      executor.call(intent.generator_args, destination_root)
      (addto_migrations(destination_root) - before).max ||
        addto_migrations(destination_root).max
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

    private

    def addto_migrations(destination_root)
      Dir.glob(File.join(destination_root.to_s, "db", "migrate", "*_inline_forms_add_to_*.rb"))
    end
  end
end
