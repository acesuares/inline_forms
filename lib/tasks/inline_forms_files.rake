# -*- encoding : utf-8 -*-

# Declared file slots (InlineForms::StoredFiles) and the file trash.
namespace :inline_forms do
  namespace :file_trash do
    desc "Purge trashed files whose retention has passed (run daily from cron; exits non-zero on failure)"
    task purge_expired: :environment do
      purged = InlineForms::FileTrashSweep.run!
      puts "inline_forms: file trash sweep purged #{purged} file(s)"
      Rails.logger.info("inline_forms: file trash sweep purged #{purged} file(s)")
    end
  end

  namespace :files do
    # Models that declare file slots. Eager-loads the app so every model is known.
    def inline_forms_file_slot_models
      Rails.application.eager_load!
      ActiveRecord::Base.descendants.select do |klass|
        !klass.abstract_class? && klass.respond_to?(:inline_forms_file_slots) &&
          klass.inline_forms_file_slots.any? && klass.table_exists?
      end
    end

    desc "Report broken file slots (read-only): bytes without a filename, a filename without bytes"
    task audit: :environment do
      problems = 0
      inline_forms_file_slot_models.each do |klass|
        klass.inline_forms_file_slots.each do |attribute, slot|
          scope = klass.unscoped
          orphaned = scope.where.not(slot[:data] => nil).where(attribute => [ nil, "" ]).count
          missing = scope.where(slot[:data] => nil).where.not(attribute => [ nil, "" ]).count
          next if orphaned.zero? && missing.zero?

          problems += orphaned + missing
          puts "#{klass.name}##{attribute}: #{orphaned} with bytes but no filename (orphaned), " \
               "#{missing} with a filename but no bytes (empty downloads)"
        end
      end
      puts(problems.zero? ? "inline_forms: all file slots consistent" :
           "inline_forms: #{problems} inconsistent slot(s). Orphaned bytes: `rake inline_forms:files:trash_orphans CONFIRM=yes` " \
           "moves them to the trash (purged by the retention sweep). Missing bytes cannot be repaired here; restore from a backup.")
    end

    desc "Move orphaned bytes (bytes in a slot without a filename) into the file trash. Needs CONFIRM=yes"
    task trash_orphans: :environment do
      abort "inline_forms: refusing without CONFIRM=yes (run inline_forms:files:audit first)" unless ENV["CONFIRM"] == "yes"

      moved = 0
      inline_forms_file_slot_models.each do |klass|
        klass.inline_forms_file_slots.each do |attribute, slot|
          ids = klass.unscoped.where.not(slot[:data] => nil).where(attribute => [ nil, "" ]).pluck(klass.primary_key)
          ids.each do |id|
            record = klass.unscoped.find(id)
            moved += 1 if record.inline_forms_remove_file!(attribute, by: nil, reason: :orphaned)
          end
        end
      end
      puts "inline_forms: moved #{moved} orphaned file(s) to the trash"
    end
  end
end
