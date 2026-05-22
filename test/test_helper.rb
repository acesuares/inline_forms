# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails"
require "minitest/autorun"
require "inline_forms/form_element_from_callee"
require "inline_forms"

InlineForms::FormElementRegistry.apply!
