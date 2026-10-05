# frozen_string_literal: true

require_relative "../integration_test_helper"

# Host apps run a CSP with script-src 'nonce-…' (StProject; the dummy app is
# configured the same way, report-only). Every inline <script> the gem's
# layouts render carries the request's nonce, and the nonce is published in
# a csp-nonce meta tag for the scripts Turbo inserts. The unused
# inline_forms/_flash partial (an inline jQuery <script>) is gone.
class CspNonceTest < InlineFormsIntegrationTestCase
  def header_nonce
    policy = response.headers["Content-Security-Policy-Report-Only"].to_s
    policy[/'nonce-([^']+)'/, 1]
  end

  def inline_scripts(html)
    html.scan(/<script\b[^>]*>/).reject { |tag| tag.include?(" src=") }
  end

  def assert_inline_scripts_nonced(html, nonce)
    scripts = inline_scripts(html)
    assert_predicate scripts, :any?, "the layout's Turbo module script"
    scripts.each { |tag| assert_includes tag, %(nonce="#{nonce}"), tag }
  end

  test "the inline_forms layout nonces its inline script and publishes the nonce" do
    get widgets_path

    assert_response :success
    nonce = header_nonce
    assert nonce, "precondition: the dummy sends a nonce-based CSP"
    assert_inline_scripts_nonced(response.body, nonce)
    assert_match %r{<script type="module" nonce="#{Regexp.escape(nonce)}" data-turbo-eval="false">\s*import \{ Turbo \}}, response.body
    assert_includes response.body, %(<meta name="csp-nonce" content="#{nonce}" />)
  end

  test "the application layout nonces its inline script too" do
    get widgets_path
    nonce = header_nonce
    html = controller.render_to_string(template: "stats/show", layout: "application")

    assert_inline_scripts_nonced(html, nonce)
    assert_includes html, %(<meta name="csp-nonce" content="#{nonce}" />)
  end

  test "the unused inline_forms/_flash partial with its inline script is gone" do
    get widgets_path
    refute controller.lookup_context.exists?("flash", [ "inline_forms" ], true)
  end
end
