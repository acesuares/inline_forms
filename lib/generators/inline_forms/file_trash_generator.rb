# -*- encoding : utf-8 -*-

require "rails/generators"
require "rails/generators/migration"

module InlineForms
  module Generators
    # `rails g inline_forms:file_trash`
    #
    # Writes the migration for the file trash of declared file slots
    # (InlineForms::StoredFiles): inline_forms_trashed_files (one row per
    # removed / replaced / uploaded file event, bytes until purged) and
    # inline_forms_file_trash_sweeps (the retention sweep's heartbeat). The
    # installer runs it for new apps; existing apps run it once by hand.
    class FileTrashGenerator < Rails::Generators::Base
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
        migration_template "create_inline_forms_file_trash.rb.erb",
                           "db/migrate/create_inline_forms_file_trash.rb"
      end
    end
  end
end
