# -*- encoding : utf-8 -*-
require "tabs_on_rails"

module InlineForms
  # Tabs_on_rails 3.0 (weppos, RubyGems) only threads the 4th argument of
  # `tab_for` into the surrounding `<li>` element; it has no way of putting
  # html attributes on the actual `<a>`. That made the gem fine for the
  # old UJS path (links did not need any extra data attributes — UJS would
  # turn anything with `data-remote="true"` into AJAX) but useless under
  # Turbo, where partial-swap behavior requires `data-turbo-frame="…"` (or
  # similar) on the link itself.
  #
  # The historical workaround was the `acesuares/tabs_on_rails` fork
  # (`update_remote_before_action`), which patched `tab_for` to thread
  # html options into `link_to`. That fork was dropped in 7.13.5; this
  # builder is its Turbo-shaped replacement.
  #
  # Usage:
  #
  #   <%= tabs_tag builder: InlineForms::TurboTabsBuilder,
  #                open_tabs: { class: "owner_tabs", id: "owner_#{@object.id}_tabs" } do |tab| %>
  #     <%= tab.naw "NAW",
  #                 owner_path(@object, tab: :naw, update: @update_span),
  #                 link_options: { data: { turbo_frame: @update_span } } %>
  #     <%= tab.apartments "Apartments",
  #                        owner_path(@object, tab: :apartments, update: @update_span),
  #                        link_options: { data: { turbo_frame: @update_span } } %>
  #   <% end %>
  #
  # `link_options:` is consumed by the builder and forwarded to `link_to`;
  # everything else still applies to the `<li>` exactly like the upstream
  # `TabsBuilder`. Active-tab highlighting still uses tabs_on_rails'
  # `current_tab?` (driven by controller `set_tab :foo`).
  class TurboTabsBuilder < TabsOnRails::Tabs::TabsBuilder
    def tab_for(tab, name, url_options, item_options = {})
      link_options = item_options.delete(:link_options) || {}

      if current_tab?(tab)
        active_class = @options[:active_class] || "current"
        existing = item_options[:class].to_s.split(/\s+/).reject(&:empty?)
        item_options[:class] = (existing + [active_class]).uniq.join(" ")
      end

      content = @context.link_to_unless(current_tab?(tab), name, url_options, link_options) do
        @context.content_tag(:span, name)
      end

      @context.content_tag(:li, content, item_options)
    end
  end
end
