# frozen_string_literal: true

require "test_helper"
require "action_view"
require "inline_forms/tabs"
require "inline_forms/turbo_tabs_builder"

# Unit coverage for the vendored tabs support (InlineForms::Tabs, 8.1.23 —
# replaces the tabs_on_rails gem). Uses a minimal view-context double; the
# rendered-through-Rails path is covered by the example app's owner tabs
# integration test.
class TabsTest < Minitest::Test
  # Quacks like the slice of ActionView the builders touch, with a fixed
  # current tab.
  class FakeContext
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::CaptureHelper

    attr_accessor :output_buffer

    def initialize(current_tab_name)
      @current_tab_name = current_tab_name
      @output_buffer = ActionView::OutputBuffer.new
    end

    def current_tab(_namespace = nil)
      @current_tab_name
    end
  end

  def test_default_builder_marks_active_tab_with_current_class_and_span
    builder = InlineForms::Tabs::TabsBuilder.new(FakeContext.new(:home))

    active = builder.tab_for(:home, "Home", "/home")
    other  = builder.tab_for(:away, "Away", "/away")

    assert_includes active, %(class="current")
    assert_includes active, "<span>Home</span>"
    refute_includes active, "<a"
    assert_includes other, %(<a href="/away">Away</a>)
  end

  def test_default_builder_honors_custom_active_class
    builder = InlineForms::Tabs::TabsBuilder.new(FakeContext.new(:home), active_class: "is-active")
    assert_includes builder.tab_for(:home, "Home", "/home"), %(class="is-active")
  end

  def test_turbo_builder_threads_link_options_and_aria_state
    builder = InlineForms::TurboTabsBuilder.new(FakeContext.new(:naw), active_class: "is-active")

    active = builder.tab_for(:naw, "NAW", "/owners/1?tab=naw",
                             class: "tabs-title",
                             link_options: { data: { turbo_frame: "owner_1" } })
    other = builder.tab_for(:apartments, "Apartments", "/owners/1?tab=apartments",
                            class: "tabs-title",
                            link_options: { data: { turbo_frame: "owner_1" } })

    # Active: li gets both classes, anchor has no href, aria advertises state.
    assert_includes active, %(class="tabs-title is-active")
    assert_includes active, %(aria-current="page")
    assert_includes active, %(aria-selected="true")
    refute_includes active, "href="

    # Inactive: real link with the turbo-frame data attribute threaded through.
    assert_includes other, %(href="/owners/1?tab=apartments")
    assert_includes other, %(data-turbo-frame="owner_1")
    assert_includes other, %(aria-selected="false")
  end

  def test_controller_mixin_set_and_query_tabs
    # Exercise the instance methods directly through a bare object.
    holder = Object.new
    holder.extend(instance_methods_module)

    holder.send(:set_tab, :owner)
    holder.send(:set_tab, :naw, :subtabs)

    assert_equal :owner, holder.send(:current_tab)
    assert_equal :naw, holder.send(:current_tab, :subtabs)
    assert holder.send(:current_tab?, :owner)
    assert holder.send(:current_tab?, "owner")
    refute holder.send(:current_tab?, :other)
    assert holder.send(:current_tab?, :naw, :subtabs)
  end

  private

  # The Concern's `included` hook calls before_action/helper machinery that a
  # plain Object lacks; grab just the protected instance methods.
  def instance_methods_module
    mod = Module.new
    %i[set_tab current_tab current_tab? tab_stack].each do |name|
      mod.define_method(name, InlineForms::Tabs::Controller.instance_method(name))
    end
    mod
  end
end
