# frozen_string_literal: true

# Mirrors the initializer the installer seeds in host apps; the header
# (`inline_forms/_header`) iterates MODEL_TABS for admin users. Kept empty so
# the dummy needs no CanCan (`can?` is only called per entry).
MODEL_TABS = %w[].freeze

# An app's own prepare block, as a host's initializer has one (yavetracker
# includes its vendored element here). The engine's model check must run
# after it (review_fixes_8_1_85_test).
Rails.application.config.to_prepare do
  # nothing: only its place in the prepare callbacks is tested
end
