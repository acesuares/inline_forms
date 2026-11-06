# frozen_string_literal: true

require_relative "../integration_test_helper"

# Top-bar submenus after a Turbo Drive visit. Turbo replaced <body> and re-ran
# the inline_forms bundle (a fresh jQuery, its own Foundation plugin data),
# and until that finished the new body's submenus showed as plain lists;
# StProject, Scouting and Papiamentu each carried the same layout copy to
# hide them (html.no-js, a turbo:load re-init, a CSS rule). Now the gem does.
class TurboMenuTest < InlineFormsIntegrationTestCase
  ROOT = File.expand_path("../..", __dir__)

  test "the layout starts as no-js" do
    get widgets_path

    assert_response :success
    assert_match %r{<html lang="en" class="no-js">}, response.body
    # Not data-turbo-eval="false": a Turbo visit from a page whose layout
    # lacks the bundle has to run it.
    assert_match %r{<script src="[^"]*/inline_forms/inline_forms[^"]*\.js"></script>}, response.body
  end

  test "inline_forms.js boots once and re-initialises Foundation on turbo:load" do
    js = File.read(File.join(ROOT, "app/assets/javascripts/inline_forms/inline_forms.js"))
    boot = js[/if \(!window\.inlineFormsBooted\) \{.*?\n\}\n/m]

    assert boot, "the DOM-ready and turbo:load wiring sits behind the once-guard"
    turbo_load = boot[/addEventListener\("turbo:load".*?\n  \}\);/m]
    assert_includes turbo_load, "window.jQuery(document).foundation();"
    assert_includes turbo_load, "initInlineFormsWidgets(document);"
  end

  test "uninitialised submenus stay hidden after a visit" do
    scss = File.read(File.join(ROOT, "app/assets/stylesheets/inline_forms/inline_forms.scss"))

    assert_match(/^\.dropdown\.menu > li > ul\.menu:not\(\.is-dropdown-submenu\) \{\n  display: none;\n\}/, scss)
  end

  # Compiled CSS is checked in the example app (example_app_stylesheet_test).
  test "tippy.css is inlined, not left as a plain CSS @import the browser 404s on" do
    scss = File.read(File.join(ROOT, "app/assets/stylesheets/inline_forms/foundation_and_overrides.scss"))

    refute_match(/^\s*@import\s+['"][^'"]*tippy\.css['"]/, scss)
    assert_includes scss, "@include meta.load-css('../../../vendor/assets/stylesheets/tippy');"
  end
end
