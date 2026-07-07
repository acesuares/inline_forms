# -*- encoding : utf-8 -*-

require "inline_forms/tabs"

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
  # `TabsBuilder`. Active-tab highlighting still uses `current_tab?` (driven
  # by controller `set_tab :foo`).
  #
  # Since 8.1.23 this subclasses the vendored InlineForms::Tabs::TabsBuilder
  # (tabs_on_rails itself is no longer a dependency). The builder contract is
  # duck-typed, so this class also still works if a pre-8.1.23 app renders it
  # through the tabs_on_rails gem's `tabs_tag`.
  class TurboTabsBuilder < InlineForms::Tabs::TabsBuilder
    def tab_for(tab, name, url_options, item_options = {})
      link_options = item_options.delete(:link_options) || {}
      active = current_tab?(tab)

      if active
        active_class = @options[:active_class] || "current"
        existing = item_options[:class].to_s.split(/\s+/).reject(&:empty?)
        item_options[:class] = (existing + [ active_class ]).uniq.join(" ")
      end

      # The active label is rendered as an `<a>` *without* an href so that
      # CSS frameworks (Foundation 6, Bootstrap, ...) that style
      # `.tabs-title.is-active > a` (or use `[aria-selected='true']`) pick
      # it up just like the inactive tabs. Skipping the href keeps the
      # active tab non-clickable, and `aria-current="page"` advertises
      # the selection state to assistive tech / Foundation's CSS.
      content =
        if active
          @context.content_tag(:a, name,
            link_options.merge("aria-current" => "page",
                               "aria-selected" => "true"))
        else
          @context.link_to(name, url_options,
            link_options.merge("aria-selected" => "false"))
        end

      @context.content_tag(:li, content, item_options)
    end
  end
end
