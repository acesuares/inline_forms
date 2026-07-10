# frozen_string_literal: true

# Mirrors the initializer the installer seeds in host apps; the header
# (`inline_forms/_header`) iterates MODEL_TABS for admin users. Kept empty so
# the dummy needs no CanCan (`can?` is only called per entry).
MODEL_TABS = %w[].freeze
