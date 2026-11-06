# frozen_string_literal: true

require "test_helper"

# The compiled admin and devise stylesheets (test_helper runs dartsass:build).
# Tippy's CSS was a plain CSS `@import '…/tippy.css'` that the browser
# resolved to /vendor/assets/stylesheets/tippy.css, a 404 on every page; the
# gem now inlines it. And the top-bar submenus stay hidden until Foundation
# initialises them, also after a Turbo Drive visit (html.no-js is gone then).
class ExampleAppStylesheetTest < ActiveSupport::TestCase
  %w[inline_forms devise].each do |entry|
    test "builds/inline_forms/#{entry}.css inlines tippy and has no CSS @import" do
      css = built(entry)

      assert_empty css.scan(/@import[^;]*;/), "#{entry}.css: the browser would fetch these"
      assert_includes css, ".tippy-box{position:relative"
    end
  end

  test "uninitialised top-bar submenus are hidden" do
    assert_includes built("inline_forms"), ".dropdown.menu>li>ul.menu:not(.is-dropdown-submenu){display:none}"
  end

  private

  def built(entry)
    path = Rails.root.join("app/assets/builds/inline_forms/#{entry}.css")
    assert path.file?, "#{path} missing; dartsass:build did not run"
    path.read
  end
end
