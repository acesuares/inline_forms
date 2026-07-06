# -*- encoding : utf-8 -*-

module InlineForms
  # Vendored replacement for the tabs_on_rails gem (8.1.23).
  #
  # inline_forms used tabs_on_rails 3.0.0 (MIT, Copyright (c) 2009-2017
  # Simone Carletti <weppos@weppos.net>; last released 2017) for exactly four
  # things: the controller `set_tab` DSL, the `current_tab`/`current_tab?`
  # helpers, the `tabs_tag` view helper, and the `TabsBuilder` base class that
  # InlineForms::TurboTabsBuilder subclasses. This file ports that surface —
  # API-compatible with the gem — so generated apps no longer need an
  # unmaintained dependency (which was also an *undeclared* one: the engine
  # required "tabs_on_rails" but the gemspec never listed it; only the
  # installer-written Gemfile made it load).
  #
  # The port keeps upstream semantics:
  #
  #   class OwnersController < ApplicationController
  #     set_tab :owner                     # class-level, uses before_action
  #     set_tab :naw, :subtabs, only: :show
  #   end
  #
  #   <%= tabs_tag builder: InlineForms::TurboTabsBuilder do |tab| %>
  #     <%= tab.naw "NAW", owner_path(@object, tab: :naw) %>
  #   <% end %>
  #
  # If the host app still bundles the tabs_on_rails gem (apps generated before
  # 8.1.23), the engine skips its own controller include and leaves the gem's
  # identical implementation in charge — see the engine initializer in
  # lib/inline_forms.rb.
  module Tabs
    # Controller mixin: tab state lives in @tab_stack per namespace.
    module Controller
      extend ActiveSupport::Concern

      included do
        extend ClassMethods
        helper HelperMethods
        helper_method :current_tab, :current_tab?
      end

      protected

      def set_tab(name, namespace = nil)
        tab_stack[namespace || :default] = name
      end

      def current_tab(namespace = nil)
        tab_stack[namespace || :default]
      end

      def current_tab?(name, namespace = nil)
        current_tab(namespace).to_s == name.to_s
      end

      def tab_stack
        @tab_stack ||= {}
      end

      module ClassMethods
        # set_tab :foo
        # set_tab :foo, only: [:index, :show]
        # set_tab :foo, :namespace, except: :new
        def set_tab(*args)
          options = args.extract_options!
          name, namespace = args

          before_action(options) do |controller|
            controller.send(:set_tab, name, namespace)
          end
        end
      end

      module HelperMethods
        def tabs_tag(options = {}, &block)
          Renderer.new(self, { namespace: :default }.merge(options)).render(&block)
        end
      end
    end

    # Renders a tab group: open tag, one tab_for per named tab, close tag.
    # `tab.anything(...)` is dispatched to the builder's tab_for via
    # method_missing, exactly like upstream.
    class Renderer
      def initialize(context, options = {})
        @context = context
        @builder = (options.delete(:builder) || TabsBuilder).new(@context, options)
        @options = options
      end

      def open_tabs(*args)
        call_builder(:open_tabs, *args)
      end

      def close_tabs(*args)
        call_builder(:close_tabs, *args)
      end

      def method_missing(*args, &block)
        @builder.tab_for(*args, &block)
      end

      def respond_to_missing?(_name, _include_private = false)
        true
      end

      def render(&block)
        raise LocalJumpError, "no block given" unless block_given?

        options = @options.dup
        open_tabs_options  = options.delete(:open_tabs)  || {}
        close_tabs_options = options.delete(:close_tabs) || {}

        "".dup.tap do |html|
          html << open_tabs(open_tabs_options).to_s
          html << @context.capture(self, &block)
          html << close_tabs(close_tabs_options).to_s
        end.html_safe
      end

      private

      def call_builder(name, *args)
        method = @builder.method(name)
        method.arity.zero? ? method.call : method.call(*args)
      end
    end

    # Abstract builder API (initialize signature is part of the contract:
    # custom builders from either this module or the old gem are duck-typed
    # against it).
    class Builder
      def initialize(context, options = {})
        @context   = context
        @namespace = options.delete(:namespace) || :default
        @options   = options
      end

      def current_tab?(tab)
        tab.to_s == @context.current_tab(@namespace).to_s
      end

      def tab_for(*args)
        raise NotImplementedError
      end

      def open_tabs(*args); end

      def close_tabs(*args); end
    end

    # Default builder: <ul> of <li><a>, active tab as <li class="current"><span>.
    class TabsBuilder < Builder
      def tab_for(tab, name, url_options, item_options = {})
        if current_tab?(tab)
          item_options[:class] = item_options[:class].to_s.split(" ")
                                                     .push(@options[:active_class] || "current")
                                                     .join(" ")
        end
        content = @context.link_to_unless(current_tab?(tab), name, url_options) do
          @context.content_tag(:span, name)
        end
        @context.content_tag(:li, content, item_options)
      end

      def open_tabs(options = {})
        @context.tag("ul", options, true)
      end

      def close_tabs(_options = {})
        "</ul>".html_safe
      end
    end
  end
end
