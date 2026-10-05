# frozen_string_literal: true

require_relative "../integration_test_helper"

# The gem's own strings resolve in en and nl, also under
# raise_on_missing_translations (StProject switched to :nl with :strict):
# the create flash (`success`, misspelled `succes` in both locale files), the
# versions panel (was hard-coded English), the nl view keys that were missing
# (restore, list_versions, close_versions_list, undelete), localized version
# timestamps, the Devise layout's lang and the sign-in button.
class LocaleTest < InlineFormsIntegrationTestCase
  KEYS = %w[
    success
    inline_forms.view.restore inline_forms.view.list_versions inline_forms.view.close_versions_list
    inline_forms.view.undelete inline_forms.view.versions inline_forms.view.versions_event
    inline_forms.view.versions_when inline_forms.view.versions_done_by inline_forms.view.versions_changeset
    inline_forms.view.versions_old_value inline_forms.view.versions_new_value inline_forms.view.versions_empty
    inline_forms.view.versions_rich_text inline_forms.view.version_events.create
    inline_forms.view.version_events.update inline_forms.view.version_events.destroy
    inline_forms.devise.login common.more common.logout
  ].freeze

  setup do
    @machine = Machine.create!(name: "Press")
    @machine.update!(name: "Press 2")
  end

  teardown do
    I18n.backend.reload!
  end

  # Every translation the request looks up must exist: a missing one raises,
  # in the views and in the controller (create's flash).
  def strictly(locale)
    original_view = ActionView::Helpers::TranslationHelper.raise_on_missing_translations
    original_handler = I18n.exception_handler
    original_default = I18n.default_locale
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = true
    I18n.exception_handler = ->(exception, *) { raise exception.respond_to?(:to_exception) ? exception.to_exception : exception }
    # with_locale first: it restores the locale it found, so the thread's
    # locale must not be read after default_locale changed (it would then
    # restore :nl for every later test).
    I18n.with_locale(locale) do
      I18n.default_locale = locale
      yield
    end
  ensure
    I18n.default_locale = original_default
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = original_view
    I18n.exception_handler = original_handler
  end

  test "the gem's keys exist in en and nl, and the misspelled succes is gone" do
    %i[en nl].each do |locale|
      KEYS.each { |key| assert I18n.exists?(key, locale), "#{locale}.#{key}" }
      refute I18n.exists?("succes", locale), "#{locale}.succes"
    end
    assert_equal "Machine created.", I18n.t("success", message: "Machine", locale: :en)
    assert_equal "Machine is aangemaakt.", I18n.t("success", message: "Machine", locale: :nl)
  end

  test "create's success flash translates in nl" do
    # The model top bar shows t(controller_name): host-supplied, like
    # StProject's `clients: cliënten`.
    I18n.backend.store_translations(:nl, machines: "machines")
    strictly(:nl) do
      post machines_path(update: "machines_list"), params: { name: "Lathe" }, headers: frame_headers("machines_list")
    end

    assert_response :success
    assert_equal "Machine is aangemaakt.", controller.flash[:success]
  end

  test "the versions panel and list are translated, with localized timestamps" do
    row = "machine_#{@machine.id}"
    strictly(:nl) do
      get machine_path(@machine, update: row), headers: frame_headers(row)
      assert_response :success
      assert_includes response.body, "Versies (2)"

      get list_versions_machine_path(@machine, update: row), headers: frame_headers(row)
    end

    assert_response :success
    body = response.body
    %w[Versies Gebeurtenis Wanneer Door Wijzigingen aangemaakt gewijzigd terugzetten].each do |text|
      assert_includes body, text
    end
    refute_includes body, "<strong>Event</strong>"
    version = @machine.versions.last
    assert_includes body, ERB::Util.h(I18n.l(version.created_at, format: :short, locale: :nl))
  end

  test "the versions list in en keeps its English labels" do
    row = "machine_#{@machine.id}"
    strictly(:en) do
      get list_versions_machine_path(@machine, update: row), headers: frame_headers(row)
    end

    assert_response :success
    assert_includes response.body, "Versions (2)"
    assert_includes response.body, "<strong>Event</strong>"
    assert_includes response.body, "old value"
  end

  test "the devise and application layouts declare the page language" do
    get widgets_path
    I18n.with_locale(:nl) do
      assert_includes controller.render_to_string(template: "stats/show", layout: "devise"), %(<html lang="nl">)
      assert_includes controller.render_to_string(template: "stats/show", layout: "application"), %(<html lang="nl">)
    end
  end
end
