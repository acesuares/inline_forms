# frozen_string_literal: true

require_relative "../integration_test_helper"

# Top-bar submenus after a Turbo Drive visit. The bundle sat in <body>, so
# Turbo re-ran it on every visit (a fresh jQuery, its own Foundation plugin
# data), and until that finished the new body's submenus showed as plain
# lists; StProject, Scouting and Papiamentu each carried the same layout copy
# to hide them (html.no-js, a turbo:load re-init, a CSS rule). Now the gem
# loads the bundle in <head>, which Turbo runs once.
class TurboMenuTest < InlineFormsIntegrationTestCase
  ROOT = File.expand_path("../..", __dir__)

  def boot_block
    js = File.read(File.join(ROOT, "app/assets/javascripts/inline_forms/inline_forms.js"))
    js[/^if \(!window\.inlineFormsBooted\) \{.*?\n\}\n/m]
  end

  test "the layout starts as no-js and loads the bundle in head" do
    get widgets_path

    assert_response :success
    assert_match %r{<html lang="en" class="no-js">}, response.body
    head = response.body[%r{<head>.*</head>}m]
    scripts = %w[popper.min tippy-bundle.umd.min inline_forms/inline_forms].map { |name|
      head.index(%r{<script src="[^"]*/#{Regexp.escape(name)}[^"]*\.js"></script>})
    }
    assert scripts.all?, "popper, tippy and inline_forms.js are in <head>"
    assert_equal scripts.sort, scripts, "in that order"
    refute_match %r{<body.*inline_forms/inline_forms[^"]*\.js}m, response.body
  end

  test "inline_forms.js wires every document listener once, and boots once per body" do
    boot = boot_block

    assert boot, "the listeners sit behind the once-guard"
    rest = File.read(File.join(ROOT, "app/assets/javascripts/inline_forms/inline_forms.js")).sub(boot, "")
    refute_match(/addEventListener|\$\(document\)|\.ready\(/, rest.gsub(%r{^\s*//.*$}, "").gsub(/el\.addEventListener\("input"/, ""),
      "no document listener outside the guard: a host layout with the bundle in <body> re-runs it on every visit")
    %w[turbo:load turbo:frame-load mouseover].each do |event|
      assert_includes boot, "document.addEventListener(\"#{event}\""
    end
    assert_includes boot, "document.body === inlineFormsBootedBody"
    assert_includes boot, "window.jQuery(document).foundation();"
  end

  test "uninitialised dropdown submenus stay hidden, drilldown menus are left alone" do
    scss = File.read(File.join(ROOT, "app/assets/stylesheets/inline_forms/inline_forms.scss"))

    assert_match(/^\.dropdown\.menu\[data-dropdown-menu\] > li > ul\.menu:not\(\.is-dropdown-submenu\) \{\n  display: none;\n\}/, scss)
  end

  # Compiled CSS is checked in the example app (example_app_stylesheet_test).
  test "tippy.css is inlined, not left as a plain CSS @import the browser 404s on" do
    scss = File.read(File.join(ROOT, "app/assets/stylesheets/inline_forms/foundation_and_overrides.scss"))

    refute_match(/^\s*@import\s+['"][^'"]*tippy\.css['"]/, scss)
    assert_includes scss, "@include meta.load-css('../../../vendor/assets/stylesheets/tippy');"
  end
end
