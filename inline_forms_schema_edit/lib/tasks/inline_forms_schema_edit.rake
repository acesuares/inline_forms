# -*- encoding : utf-8 -*-

require "shellwords"

# The pipeline's command-line surface (phases 2-4 of
# stuff/2026-07-11-schema-gui-gem-and-automated-pipeline-plan.md).
#
# Tenant side:   export_batch, mark_batch, apply_due
# Checkout side: apply_batch (replay into this checkout; no migrate, no commit)
namespace :schema_edit do
  desc "Export a frozen batch as JSON (stdout, or FILE=path). Usage: schema_edit:export_batch[batch_id]"
  task :export_batch, [ :batch_id ] => :environment do |_t, args|
    batch = InlineForms::SchemaBatch.find(args.fetch(:batch_id))
    abort "Batch #{batch.id} is still a draft — submit it first." if batch.draft?

    json = InlineFormsSchemaEdit::BatchExport.to_json(batch)
    if ENV["FILE"].to_s.empty?
      puts json
    else
      File.write(ENV["FILE"], json)
      puts "Wrote batch #{batch.id} (#{batch.intents.size} intents) to #{ENV['FILE']}"
    end
  end

  desc "Replay an exported batch into THIS checkout (codegen only; no db:migrate, no commit). Usage: schema_edit:apply_batch[export.json]"
  task :apply_batch, [ :file ] => :environment do |_t, args|
    file = args.fetch(:file)
    abort "No such file: #{file}" unless File.file?(file)

    # Refuse to replay onto a dirty tree: the generated diff must be exactly
    # this batch, nothing else (SKIP_GIT_CHECK=1 to override, e.g. in tests).
    if ENV["SKIP_GIT_CHECK"].to_s.empty? && File.directory?(Rails.root.join(".git"))
      dirty = `git -C #{Rails.root.to_s.shellescape} status --porcelain`.strip
      abort "Working tree is not clean; commit or stash first:\n#{dirty}" unless dirty.empty?
    end

    import = InlineFormsSchemaEdit::BatchImport.from_file(file)
    result = import.apply!(destination_root: Rails.root)

    puts "Replayed #{result.applied} intent(s)."
    result.plan.each { |line| puts "  plan: #{line}" }
    result.migrations.each { |m| puts "  migration: #{m}" }
    result.labels.each { |l| puts "  label: #{l}" }
    puts "NOT migrated, NOT committed — run the test gate, then commit."
  rescue InlineFormsSchemaEdit::BatchImport::ImportError => e
    abort "Import failed: #{e.message}"
  end

  desc "Report pipeline progress on a batch (CI-side helper against the tenant DB). Usage: schema_edit:mark_batch[batch_id,status] GIT_SHA=... ERROR=..."
  task :mark_batch, [ :batch_id, :status ] => :environment do |_t, args|
    batch = InlineForms::SchemaBatch.find(args.fetch(:batch_id))
    batch.transition!(args.fetch(:status), git_sha: ENV["GIT_SHA"].presence, error: ENV["ERROR"].presence)
    puts "Batch #{batch.id}: #{batch.status}"
  end

  desc "Apply due batches (phase 4): for each ready batch whose window has arrived, run db:migrate, mark applied, run the configured restart command"
  task apply_due: :environment do
    due = InlineForms::SchemaBatch.with_status(:ready).select(&:due_for_apply?)
    if due.empty?
      puts "No batches due."
      next
    end

    due.each do |batch|
      puts "Applying batch #{batch.id} (window: #{batch.window_at || 'next window'})..."
      begin
        # Additive-only migrations (the GUI vocabulary guarantees it), so
        # migrating ahead of the restart is safe (expand/contract).
        ActiveRecord::Tasks::DatabaseTasks.migrate
        batch.transition!(:applied)
        puts "  migrated + marked applied."

        if (cmd = InlineFormsSchemaEdit.restart_command).present?
          puts "  restart: #{cmd}"
          system(cmd) || puts("  WARNING: restart command exited non-zero")
        end
      rescue StandardError => e
        batch.transition!(:failed, error: "apply_due: #{e.class}: #{e.message}")
        puts "  FAILED: #{e.message} (batch marked failed)"
      end
    end
  end
end
