# -*- encoding : utf-8 -*-

# One row per run of the retention sweep (`rake inline_forms:file_trash:
# purge_expired`): the heartbeat the global trash page shows, so a cron job
# that silently stopped is visible to a human.
class InlineForms::FileTrashSweep < ActiveRecord::Base
  self.table_name = "inline_forms_file_trash_sweeps"

  # A sweep older than this is reported as overdue (daily cron + slack).
  OVERDUE_AFTER = 48.hours

  def self.last_run
    order(ran_at: :desc, id: :desc).first
  end

  def self.overdue?
    return false if InlineForms.file_trash_retention.nil?

    last = last_run
    last.nil? || last.ran_at < OVERDUE_AFTER.ago
  end

  # Runs the sweep and records it. Re-raises after recording a failure, so
  # the rake task exits non-zero and cron mails it.
  def self.run!
    purged = InlineForms::TrashedFile.purge_expired!
    create!(ran_at: Time.current, purged_count: purged)
    purged
  rescue StandardError => e
    begin
      create!(ran_at: Time.current, purged_count: 0, error: "#{e.class}: #{e.message}".truncate(1000))
    rescue StandardError
      nil
    end
    raise
  end
end
