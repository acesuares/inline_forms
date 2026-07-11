# -*- encoding : utf-8 -*-

require "digest"
require "json"

module InlineFormsSchemaGui
  # Serializes a frozen SchemaBatch for transport to the CI/dev side, sealed
  # with a content digest. The digest is computed over the canonical JSON of
  # the ordered intent list only (not timestamps/ids), so the same logical
  # batch always digests identically; SchemaBatch#submit! stores it and
  # BatchImport re-verifies it before replaying.
  module BatchExport
    FORMAT = 1

    module_function

    def digest_for(batch)
      canonical = JSON.generate(batch.intents.reload.map(&:as_export))
      "sha256:#{Digest::SHA256.hexdigest(canonical)}"
    end

    def payload(batch)
      {
        "format" => FORMAT,
        "batch" => {
          "id"           => batch.id,
          "status"       => batch.status,
          "requested_by" => batch.requested_by,
          "submitted_at" => batch.submitted_at&.iso8601,
          "window_at"    => batch.window_at&.iso8601
        },
        "intents" => batch.intents.map(&:as_export),
        "digest"  => batch.content_digest || digest_for(batch)
      }
    end

    def to_json(batch)
      JSON.pretty_generate(payload(batch))
    end
  end
end
