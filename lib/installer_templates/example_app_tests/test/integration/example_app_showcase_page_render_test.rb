# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Smoke test for the full FormElementShowcase show page. Covers the
# display-only helpers (`header`, `info`, `info_list`) and the show
# branches of every uploader helper + rich_text.
class ExampleAppShowcasePageRenderTest < ExampleAppIntegrationTestCase
  # All non-header attributes on FormElementShowcase that should each
  # be wrapped in a `<turbo-frame id="form_element_showcase_<id>_<attr>">`.
  SHOWCASE_FIELD_ATTRIBUTES = %i[
    title
    body_plain_area
    count
    price
    amount
    meeting_date
    meeting_time
    birth_month
    start_month
    is_active
    gender
    rating_int
    priority
    priority2
    stars
    scale_int
    scale_val
    attachment
    jingle
    cover
    description
    roles
    created_at
    updated_at
  ].freeze

  SHOWCASE_HEADER_ATTRIBUTES = %i[
    header_basics
    header_numbers
    header_dates
    header_choices
    header_files
    header_rich
    header_meta
  ].freeze

  setup do
    locale = Locale.find_or_create_by!(name: "en") { |l| l.title = "English" }
    @role = Role.find_or_create_by!(name: "superadmin") { |r| r.description = "Super Admin" }

    @full = FormElementShowcase.find_or_create_by!(title: "Full demo") do |s|
      s.body_plain_area = "Plain text body"
      s.count           = 7
      s.price           = "12.34"
      s.meeting_date    = Date.new(2026, 6, 1)
      s.meeting_time    = Time.utc(2000, 1, 1, 14, 30)
      s.birth_month     = 7
      s.start_month     = Date.new(2026, 9, 1)
      s.is_active       = true
      s.gender          = 1
      s.rating_int      = 2
      s.priority        = 2
      s.priority2       = 3
      s.stars           = 4
      s.scale_int       = 3
      s.scale_val       = 2
      s.amount          = Money.from_amount(99.95, "USD") if s.respond_to?(:amount=) && defined?(Money)
      s.description     = "<p>A rich-text body.</p>"
    end
    @full.roles << @role unless @full.roles.where(id: @role.id).exists?

    @empty = FormElementShowcase.find_or_create_by!(title: "Empty demo") do |s|
      # Keep dropdown/scale integers at valid indices so the show helpers
      # do not crash on nil. The point of "empty demo" is that roles and
      # uploads are blank, not every integer attribute.
      s.gender     = 1
      s.rating_int = 1
      s.priority   = 1
      s.priority2  = 1
      s.stars      = 1
      s.scale_int  = 1
      s.scale_val  = 1
    end
  end

  test "full showcase show page renders every per-attribute turbo-frame" do
    row_frame = "form_element_showcase_#{@full.id}"
    get form_element_showcase_path(@full, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    assert_response :success

    SHOWCASE_FIELD_ATTRIBUTES.each do |attr|
      frame = "form_element_showcase_#{@full.id}_#{attr}"
      assert_includes @response.body, %(<turbo-frame id="#{frame}">),
        "expected per-attribute frame for #{attr}"
    end

    SHOWCASE_HEADER_ATTRIBUTES.each do |attr|
      label = FormElementShowcase.human_attribute_name(attr)
      assert_includes @response.body, label,
        "expected header label for #{attr} (#{label.inspect})"
    end

    assert_includes @response.body, @role.name,
      "expected info_list to render the role's _presentation"
  end

  test "empty showcase info_list renders the no-roles placeholder" do
    row_frame = "form_element_showcase_#{@empty.id}"
    get form_element_showcase_path(@empty, update: row_frame),
        headers: { "Turbo-Frame" => row_frame, "Accept" => "text/html" }

    assert_response :success
    frame = "form_element_showcase_#{@empty.id}_roles"
    body = @response.body
    assert_includes body, %(<turbo-frame id="#{frame}">)
    frame_block = body[body.index(%(<turbo-frame id="#{frame}">"))..-1] rescue nil
    # info_list_show emits a `--` placeholder for empty associations.
    assert_match(/<turbo-frame id="#{frame}">[^<]*<div class='row [^']+'>--<\/div>/m, body,
      "expected info_list empty placeholder `--` inside roles frame")
  end
end
