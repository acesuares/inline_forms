# -*- encoding : utf-8 -*-

require "digest"
require "json"

module InlineFormsSchemaEdit
  # The import/replay half of the pipeline (phase 2): takes an exported
  # batch payload and materializes it into the CURRENT checkout — validates
  # every intent against this checkout's models, then replays them in order
  # through InlineForms::SchemaApply#generate! (+ SchemaLabel for labels).
  #
  # Deliberately does NOT migrate and does NOT commit: it only writes model
  # edits + migration files and reports what it did, so the same class
  # serves a developer replaying by hand and CI replaying automatically
  # (CI's job then runs the test gate, commits, builds).
  class BatchImport
    class ImportError < StandardError; end

    Result = Struct.new(:applied, :migrations, :labels, :plan, keyword_init: true)

    attr_reader :payload

    # Injectable for tests: executor replaces the addto generator run,
    # label_writer replaces SchemaLabel.write.
    def initialize(payload, executor: nil, label_writer: nil)
      @payload = payload.is_a?(String) ? JSON.parse(payload) : payload
      @executor = executor
      @label_writer = label_writer || InlineForms::SchemaLabel.method(:write)
    rescue JSON::ParserError => e
      raise ImportError, "not valid JSON: #{e.message}"
    end

    def self.from_file(path, **kwargs)
      new(File.read(path), **kwargs)
    end

    # Verify structure + digest + per-intent validity against this checkout.
    # Returns the intents array (raises ImportError on any problem).
    def verify!
      raise ImportError, "unsupported format #{payload['format'].inspect}" unless payload["format"] == BatchExport::FORMAT

      intents = payload["intents"]
      raise ImportError, "batch has no intents" if intents.blank?

      canonical = JSON.generate(intents)
      digest = "sha256:#{Digest::SHA256.hexdigest(canonical)}"
      unless digest == payload["digest"]
        raise ImportError, "digest mismatch: payload says #{payload['digest'].inspect}, content is #{digest.inspect} — batch changed after submit?"
      end

      intents.each_with_index do |intent, i|
        error = IntentValidator.error_for(intent)
        raise ImportError, "intent ##{i + 1} (#{intent['model_name']}##{intent['attribute']}): #{error}" if error
      end

      intents
    end

    # Replay all intents into destination_root. Stops at the first failure
    # (raises), leaving earlier generated files in place for inspection —
    # the caller (CI) works on a clean tree it can reset.
    def apply!(destination_root: Rails.root)
      intents = verify!
      migrations = []
      labels = []
      plan = []

      intents.each do |intent_hash|
        intent = build_intent(intent_hash)
        apply = InlineForms::SchemaApply.new(intent)
        plan.concat(apply.preview_plan)

        migration = apply.generate!(
          destination_root: destination_root,
          executor: @executor || InlineForms::SchemaApply::DEFAULT_GENERATE_EXECUTOR
        )
        migrations << migration if migration

        if intent_hash["label"].present?
          labels << @label_writer.call(
            destination_root: destination_root,
            model_class: intent.model_class,
            attribute: intent.attribute,
            label: intent_hash["label"],
            locale: intent_hash["locale"].presence || I18n.default_locale.to_s
          )
        end
      end

      Result.new(applied: intents.size, migrations: migrations, labels: labels, plan: plan)
    end

    private

    def build_intent(h)
      InlineForms::SchemaIntent.new(
        model_name:   h["model_name"],
        attribute:    h["attribute"],
        form_element: h["form_element"],
        after:        h["after"].presence,
        before:       h["before"].presence
      )
    end
  end
end
