# frozen_string_literal: true

require_relative "../example_app/example_integration_test_case"

# Choice/scale helpers on FormElementShowcase:
#   check_box                       (is_active, 0|1)
#   radio_button                    (gender, hash)
#   dropdown_with_integers          (rating_int)
#   dropdown_with_values            (priority normal + priority2 options_disabled)
#   dropdown_with_values_with_stars (stars)
#   scale_with_integers             (scale_int)
#   scale_with_values               (scale_val)
class ExampleAppShowcaseChoiceScaleFieldsTest < ExampleAppIntegrationTestCase
  setup do
    @showcase = FormElementShowcase.find_or_create_by!(title: "Choice/scale demo")
  end

  def field_frame(attr)
    "form_element_showcase_#{@showcase.id}_#{attr}"
  end

  def field_headers(attr)
    { "Turbo-Frame" => field_frame(attr), "Accept" => "text/html" }
  end

  def underscored_param_root
    "_form_element_showcase"
  end

  test "check_box toggles is_active from 0 to 1" do
    @showcase.update!(is_active: false)
    frame = field_frame(:is_active)
    put form_element_showcase_path(
      @showcase,
      attribute: "is_active",
      form_element: "check_box",
      update: frame
    ), params: { is_active: 1 }, headers: field_headers(:is_active)

    assert_response :success
    assert_equal 1, @showcase.reload.is_active ? 1 : 0
  end

  test "check_box toggles is_active back to 0 when param missing" do
    @showcase.update!(is_active: true)
    frame = field_frame(:is_active)
    put form_element_showcase_path(
      @showcase,
      attribute: "is_active",
      form_element: "check_box",
      update: frame
    ), params: {}, headers: field_headers(:is_active)

    assert_response :success
    assert_equal false, !!@showcase.reload.is_active
  end

  test "radio_button sets gender via attribute param" do
    frame = field_frame(:gender)
    put form_element_showcase_path(
      @showcase,
      attribute: "gender",
      form_element: "radio_button",
      update: frame
    ), params: { gender: 2 }, headers: field_headers(:gender)

    assert_response :success
    assert_equal 2, @showcase.reload.gender
  end

  test "dropdown_with_integers sets rating_int" do
    frame = field_frame(:rating_int)
    put form_element_showcase_path(
      @showcase,
      attribute: "rating_int",
      form_element: "dropdown_with_integers",
      update: frame
    ), params: { underscored_param_root => { rating_int: 2 } }, headers: field_headers(:rating_int)

    assert_response :success
    assert_equal 2, @showcase.reload.rating_int
  end

  test "dropdown_with_values priority round-trips" do
    frame = field_frame(:priority)
    put form_element_showcase_path(
      @showcase,
      attribute: "priority",
      form_element: "dropdown_with_values",
      update: frame
    ), params: { underscored_param_root => { priority: 3 } }, headers: field_headers(:priority)

    assert_response :success
    assert_equal 3, @showcase.reload.priority
  end

  test "dropdown_with_values priority2 disables the third option in the edit form" do
    @showcase.update!(priority2: 1)
    frame = field_frame(:priority2)
    get edit_form_element_showcase_path(
      @showcase,
      attribute: "priority2",
      form_element: "dropdown_with_values",
      update: frame
    ), headers: field_headers(:priority2)

    assert_response :success
    assert_includes @response.body, %(<turbo-frame id="#{frame}">)
    # options_disabled is [2] for priority2; that option should render with `disabled`.
    assert_match(%r{<option [^>]*disabled[^>]*value="2"|<option [^>]*value="2"[^>]*disabled}, @response.body)
  end

  test "dropdown_with_values_with_stars sets stars" do
    frame = field_frame(:stars)
    put form_element_showcase_path(
      @showcase,
      attribute: "stars",
      form_element: "dropdown_with_values_with_stars",
      update: frame
    ), params: { underscored_param_root => { stars: 5 } }, headers: field_headers(:stars)

    assert_response :success
    assert_equal 5, @showcase.reload.stars
  end

  test "scale_with_integers scale_int round-trips" do
    frame = field_frame(:scale_int)
    put form_element_showcase_path(
      @showcase,
      attribute: "scale_int",
      form_element: "scale_with_integers",
      update: frame
    ), params: { underscored_param_root => { scale_int: 4 } }, headers: field_headers(:scale_int)

    assert_response :success
    assert_equal 4, @showcase.reload.scale_int
  end

  test "scale_with_values scale_val round-trips" do
    frame = field_frame(:scale_val)
    put form_element_showcase_path(
      @showcase,
      attribute: "scale_val",
      form_element: "scale_with_values",
      update: frame
    ), params: { underscored_param_root => { scale_val: 3 } }, headers: field_headers(:scale_val)

    assert_response :success
    assert_equal 3, @showcase.reload.scale_val
  end

end
