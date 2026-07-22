# -*- encoding : utf-8 -*-

require "rails/generators"
require "rails/generators/migration"

module InlineFormsSchemaEdit
  module Generators
    # `rails g inline_forms_schema_edit:install`
    #
    # Writes the migration for the batch pipeline's two tables
    # (inline_forms_schema_batches + inline_forms_schema_intents). Run by
    # the installer when an app is created with --schema-edit; existing apps
    # adding the gem later run it by hand.
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        # Collision-free against migrations generated in the same second
        # (same policy as inline_forms_addto since 8.1.41).
        now = Time.now.utc.strftime("%Y%m%d%H%M%S")
        existing = Dir.glob(File.join(dirname, "*.rb")).map { |f| File.basename(f)[/\A\d+/] }.compact
        [ now, *existing.map(&:to_s) ].max.then do |highest|
          highest == now ? now : (highest.to_i + 1).to_s
        end
      end

      def create_migration_file
        migration_template "create_schema_edit_tables.rb.erb",
                           "db/migrate/create_inline_forms_schema_edit_tables.rb"
      end

      def copy_ci_workflow_example
        example = File.expand_path("../../../doc/schema-apply-workflow.yml.example", __dir__)
        create_file "doc/schema-apply-workflow.yml.example", File.read(example)
      end
    end
  end
end
