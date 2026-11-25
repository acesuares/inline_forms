# -*- encoding : utf-8 -*-

module InlineFormsHelper
  include InlineForms::FormElements::HelperIncludes

  def inline_forms_version
    InlineForms::VERSION
  end

  # Pattern 1 preset theming (8.1.29; stuff/user-preferences-and-theming.md).
  # Emits the <body> theme class. The host's user model opts in by responding
  # to #inline_forms_theme with one of the preset names shipped in _theme.scss
  # (default | dark | sepia | high-contrast); installer-generated user models
  # store an integer `theme` column and map it. Anonymous users, or hosts
  # without the method, get the default palette.
  def inline_forms_body_theme_class
    user = respond_to?(:current_user) ? current_user : nil
    theme = user.inline_forms_theme.to_s if user.respond_to?(:inline_forms_theme)
    theme = "default" if theme.blank? || !theme.match?(/\A[a-z][a-z-]*\z/)
    "theme-#{theme}"
  end

  # Pattern 2 theming (8.1.32): per-user color overrides as an inline <style>
  # in <head>. The host's user model opts in by responding to
  # #inline_forms_color_overrides with a hash of `--if-color-` suffix => hex,
  # e.g. { 'primary' => '#2563eb', 'accent' => '#7c3aed' }. Every key and
  # value is re-validated here before interpolation (never trust a column
  # edited outside the app), and the rules are scoped to the current theme
  # class so they win the cascade over the preset palette (same specificity,
  # later in the document).
  def inline_forms_user_color_overrides_style
    user = respond_to?(:current_user) ? current_user : nil
    return unless user.respond_to?(:inline_forms_color_overrides)

    overrides = user.inline_forms_color_overrides
    return if overrides.blank?

    rules = overrides.filter_map do |key, value|
      next unless key.to_s.match?(/\A[a-z][a-z-]*\z/)
      next unless value.to_s.match?(/\A#\h{6}\z/i)

      "--if-color-#{key}: #{value};"
    end
    return if rules.empty?

    css = "body.#{inline_forms_body_theme_class} { #{rules.join(' ')} }"
    content_tag(:style, css.html_safe, id: "inline_forms_user_color_overrides")
  end

  # Returns versions for `object`, merged with versions of any associated
  # `ActionText::RichText` records (Rails `has_rich_text :foo` declarations).
  #
  # Rich-text bodies live in the polymorphic `action_text_rich_texts` table,
  # so `has_paper_trail` on the parent model (e.g. Apartment) never sees
  # rich-text edits. The generated app installs an initializer
  # (`config/initializers/rich_text_paper_trail.rb`) that declares
  # `has_paper_trail` on `ActionText::RichText` itself; this helper is what
  # surfaces those versions inside the parent's versions list view
  # (`app/views/inline_forms/_versions_list.html.erb`).
  #
  # Each entry is a Hash:
  #   :version        => the PaperTrail::Version
  #   :kind           => :primary (parent model) or :rich_text
  #   :rich_text_name => for :rich_text entries, the attribute name
  #                      (e.g. "description"); nil for :primary
  #
  # Sorted oldest-first (callers can `.reverse` for newest-first display).
  def inline_forms_versions_for(object)
    entries = object.versions.map do |v|
      { version: v, kind: :primary, rich_text_name: nil }
    end

    if InlineForms.action_text_table?
      ActionText::RichText
        .where(record_type: object.class.base_class.name, record_id: object.id)
        .each do |rich_text|
          rich_text.versions.each do |v|
            entries << {
              version: v,
              kind: :rich_text,
              rich_text_name: rich_text.name
            }
          end
        end
    end

    entries.sort_by { |entry| entry[:version].created_at }
  end

  # Turbo Frames navigation for row toolbar, versions, and nested +new+ (Step 3).
  # +update_span+ must match the target +<turbo-frame id="…">+.
  #
  # When +turbo_stream: true+ (e.g. restore from inside +*_versions+ frame), the client
  # requests +text/vnd.turbo-stream.html+ so Turbo does not expect a single matching
  # frame in the response — POSTs from nested +…_versions+ frames otherwise send
  # +Turbo-Frame: …_versions+ while the server returns the row frame (+Content missing+).
  # will_paginate renderer for a top-level list: each page link carries
  # data-turbo-action="advance", so a page change inside the list's
  # <turbo-frame> also updates the address bar (back, reload and a shared
  # link keep the page). Nested lists keep the plain renderer: their pages
  # change one panel, not the page.
  def inline_forms_advancing_link_renderer
    InlineFormsHelper.advancing_link_renderer
  end

  def self.advancing_link_renderer
    @advancing_link_renderer ||= Class.new(WillPaginate::ActionView::LinkRenderer) do
      def link(text, target, attributes = {})
        super(text, target, attributes.merge("data-turbo-action": "advance"))
      end
    end
  end

  def inline_forms_turbo_link_data(update_span, method: :get, turbo_stream: false)
    data = { turbo: true, turbo_frame: update_span }
    data[:turbo_method] = method.to_s.downcase unless method == :get
    data[:turbo_stream] = true if turbo_stream
    { data: data }
  end

  # +<turbo-frame>+ id for a list row's open/close/revert target.
  # Top-level models: +apartment_5+. Nested +not_accessible_through_html?+ children
  # (e.g. Photo under Apartment): +apartment_5_photo_2+ — must match +_list.html.erb+.
  def inline_forms_row_turbo_frame_id(object)
    frame_id = "#{object.class.name.underscore}_#{object.id}"
    return frame_id unless object.class.respond_to?(:not_accessible_through_html?) &&
      object.class.not_accessible_through_html?

    belongs_to = object.class.reflect_on_all_associations(:belongs_to)
      .find { |assoc| !assoc.polymorphic? }
    return frame_id unless belongs_to

    parent = object.public_send(belongs_to.name)
    return frame_id unless parent

    "#{parent.class.name.underscore}_#{parent.id}_#{object.class.name.underscore}_#{object.id}"
  end

  # +<turbo-frame>+ id for the versions panel on a row (+…_versions+).
  # Nested +not_accessible_through_html?+ children use the row prefix
  # (+apartment_5_photo_2_versions+), not bare +photo_2_versions+.
  def inline_forms_versions_turbo_frame_id(object)
    "#{inline_forms_row_turbo_frame_id(object)}_versions"
  end

  # Stable DOM id for the hidden HTML source of a validation-hint tooltip.
  def validation_hints_source_id(object, attribute)
    id_part = object.persisted? ? object.id : "new"
    "validation_hints_#{object.class.name.underscore}_#{id_part}_#{attribute}"
  end

  # +full_messages_for+ lines (e.g. "Name can't be blank") as a +<ul>+ for
  # Foundation tooltips with +allowHtml+; message text is HTML-escaped.
  def validation_hints_as_list_for(object, attribute)
    return "" unless object.has_validations_for?(attribute)

    messages = object.hints.full_messages_for(attribute)
    return "" if messages.empty?

    content_tag(:ul, class: "validation-hints-list") do
      safe_join(messages.map { |message| content_tag(:li, message) })
    end
  end

  private

  # close link
  def close_link(object, update_span, html_class = "button close_button", turbo_row: false)
    path = polymorphic_path(
      object,
      update: update_span,
      close: true
    )
    opts = { class: html_class, title: t("inline_forms.view.close") }
    opts[:data] = { turbo: true, turbo_frame: "_self" }
    link_to "<i class='fi-x'></i>".html_safe, path, opts
  end

  # delete link. Mind the difference between delete and destroy.
  def link_to_soft_delete(object, update_span, turbo_row: true)
    soft = ""
    if (object.soft_deletable? rescue false)
      if object.deleted? && (cancan_disabled? || (can? :soft_restore, object))
        path = send("soft_restore_#{object.class.to_s.underscore}_path", object, update: update_span)
        opts = { title: t("inline_forms.view.undelete") }
        opts.merge!(inline_forms_turbo_link_data(update_span, method: :post))
        soft = link_to "<i class='fi-refresh'></i>".html_safe, path, opts
      elsif !object.deleted? && (cancan_disabled? || (can? :soft_delete, object))
        path = send("soft_delete_#{object.class.to_s.underscore}_path", object, update: update_span)
        opts = { title: t("inline_forms.view.trash") }
        opts.merge!(inline_forms_turbo_link_data(update_span, method: :post))
        soft = link_to "<i class='fi-trash'></i>".html_safe, path, opts
      end
    end
    soft.html_safe
  end

  # destroy link. Mind the difference between delete and destroy.
  def link_to_destroy(object, update_span, turbo_row: true)
    hard = ""
    if cancan_disabled? || (can? :destroy, object)
      path = polymorphic_path(object, update: update_span)
      opts = { title: t("inline_forms.view.trash") }
      opts.merge!(inline_forms_turbo_link_data(update_span, method: :delete))
      hard = link_to "&nbsp;&nbsp;<font color='FF0000'><i class='fi-x'></i></font>".html_safe, path, opts
    end
    hard.html_safe
  end

  # new link
  #
  # +turbo_row:+ kept for API compatibility; navigation always targets +update_span+
  # as a +<turbo-frame>+ (no jquery-ujs).
  def link_to_new_record(model, path_to_new, update_span, parent_class = nil, parent_id = nil, html_class = "button new_button", turbo_row: true)
    path = send(
      path_to_new,
      update: update_span,
      parent_class: parent_class,
      parent_id: parent_id
    )
    opts = {
      class: html_class,
      title: t("inline_forms.view.add_new", model: model.model_name.human)
    }
    opts.merge!(inline_forms_turbo_link_data(update_span))
    out = link_to "<i class='fi-plus'></i>".html_safe, path, opts
    if cancan_enabled?
      if can? :create, model
        if parent_class.nil?
          raw out
        else
          raw out if can? :update, parent_class.find(parent_id), (model.to_s.tableize) # can update this specific attribute??? https://github.com/CanCanCommunity/cancancan/issues/845
        end
      end
    else
      raw out
    end
  end

  # link to versions list
  def link_to_versions_list(path_to_versions_list, object, update_span, html_class = "button new_button", turbo_row: true)
    if cancan_disabled? || can?(:list_versions, object)
      if defined?(PaperTrail) && object.respond_to?(:versions)
        path = send(path_to_versions_list, object, update: update_span)
        opts = { class: html_class, title: t("inline_forms.view.list_versions") }
        opts.merge!(inline_forms_turbo_link_data(update_span))
        raw link_to("<i class='fi-list'></i>".html_safe, path, opts)
      end
    end
  end

  # close versions list link
  def close_versions_list_link(object, update_span, html_class = "button close_button", turbo_row: true)
    path = send(
      "list_versions_#{object.class.to_s.underscore}_path",
      object,
      update: update_span,
      close: true
    )
    opts = { class: html_class, title: t("inline_forms.view.close_versions_list") }
    opts.merge!(inline_forms_turbo_link_data(update_span))
    link_to "<i class='fi-x'></i>".html_safe, path, opts
  end

  # Renders the +*_show+ helper for +form_element+, passing +turbo_frame:+ when supported.
  def inline_forms_field_show(object, attribute, form_element, turbo_frame: false)
    show_method = "#{form_element}_show"
    if turbo_frame
      send(show_method, object, attribute, turbo_frame: true)
    else
      send(show_method, object, attribute)
    end
  rescue ArgumentError
    send(show_method, object, attribute)
  end

  # Cancel control for single-field +_edit+ forms. Navigation attrs live on the outer
  # +link_to+; the visible control is +input[type=button]+ so it matches the +ok+ submit
  # height (Foundation sizes +a.button+ taller than +input.button+ in collapse rows).
  def inline_forms_field_cancel_link(object, attribute, form_element, update_span, sub_id: nil, turbo_frame: false)
    path = polymorphic_path(
      object,
      update: update_span,
      attribute: attribute,
      form_element: form_element,
      sub_id: sub_id
    )
    # The link itself is the button (an <input> inside an <a> is invalid HTML).
    opts = { class: "inline_forms-field-cancel postfix button alert", role: "button", tabindex: "-1" }
    if turbo_frame
      # Inside a <turbo-frame>: plain GET link; no data-method (legacy ujs fought Turbo).
      opts[:data] = { turbo: true, turbo_frame: "_self" }
    else
      opts[:data] = { turbo: true, turbo_frame: update_span }
    end
    link_to "cancel", path, opts
  end

  # link_to_inline_edit
  #
  # Pass +from_callee:+ +__callee__+ from the enclosing +*_show+ method so the edit route receives the correct form element name.
  # When +turbo_frame:+ is true the link targets +_self+; otherwise it targets the
  # field frame id (+css_class_id+) so edit works without a surrounding +_show+ wrap.
  def link_to_inline_edit(object, attribute, attribute_value = "", from_callee:, turbo_frame: false)
    form_element = InlineForms.form_element_string_from_callee(from_callee)
    attribute_value = attribute_value.to_s
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    value = h(attribute_value) + ("&nbsp;" * spaces).html_safe
    css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
    use_turbo_frame = turbo_frame || (@inline_forms_turbo_field == true)
    if (cancan_disabled? rescue true) || (can? :update, object, attribute)
      # some problem with concerns makes this function not available when called direct. FIXME
      link_opts = if use_turbo_frame
        { data: { turbo: true, turbo_frame: "_self" } }
      else
        { data: { turbo: true, turbo_frame: css_class_id } }
      end
      link_to value,
        edit_polymorphic_path(
          object,
          attribute: attribute.to_s,
          form_element: form_element,
          update: css_class_id),
        link_opts
    else
      h(attribute_value)
    end
  end

  # url to other language
  def locale_url(request, locale)
    subdomains = request.subdomains
    # if there are no subdomains, prepend the locale to the domain
    return request.protocol + [ locale, request.domain ].join(".") + request.port_string if subdomains.empty?
    # if there is a subdomain, find out if it's an available locale and strip it
    subdomains.shift if I18n.available_locales.include?(subdomains.first.to_sym)
    # if there are no subdomains, prepend the locale to the domain
    return request.protocol + [ locale, request.domain ].join(".") + request.port_string if subdomains.empty?
    # else return the rest
    request.protocol + [ locale, subdomains.join("."), request.domain ].join(".") + request.port_string
  end

  def translated_attribute(object, attribute)
    t("activerecord.attributes.#{object.class.name.underscore}.#{attribute}")
    #          "activerecord.attributes.#{attribute}",
    #          "attributes.#{attribute}" ] )
  end

  # get the values for an attribute
  #
  # values should be a Hash { integer => string, ... }
  #
  # or a one-dimensional array of strings
  #
  # or a Range
  #
  # A value of a values list as the user sees it: its translation, or the
  # value itself when there is none. A bare t(value) gave the view helper's
  # <span class="translation_missing"> for an untranslated value ("Ja" in
  # yavetracker), which a select option or a link escaped into raw markup.
  # Numbers (a Range's values) are shown as they are.
  def inline_forms_value_label(value)
    return value unless value.is_a?(String) || value.is_a?(Symbol)

    t(value, default: value.to_s)
  end

  def attribute_values(object, attribute)
    # if we have a range 1..6  will result in [[0,1],[1,2],[2,3],...,[5,6]]
    # or range -3..3 will result in [[0,-3],[1,-2],[2,-1],...,[6,3]]
    # if we have an array ['a','d','b'] will result in [[0,'a'],[2,'b'],[1,'d']] (sorted on value)
    # if we have a hash { 0=>'a', 2=>'b', 3=>'d' } will result in [[0,'a'],[2,'b'],[3,'d']] (it will keep the index and sort on the index)
    # TODO work this out better!
    # 2012-01-23 Use Cases
    # [ :sex, :radio_button, { 1 => 'f', 2 => 'm' } ],
    # in this case we want the attribute in the database to be 1 or 2. From that attribute, we need to find the value.
    # using an array, won't work, since [ 'f', 'm' ][1] would be 'm' in stead of 'f'
    # so values should be a hash. BUT since we don't have sorted hashes (ruby 1,.8.7), the order of the values in the edit screen will be random.
    # so we DO need an array, and look up by index (or association?).
    # [[1,'v'],[2,'m]] and then use #assoc:
    # assoc(obj) → new_ary or nil
    # Searches through an array whose elements are also arrays comparing obj with the first element of each contained array using obj.==.
    # Returns the first contained array that matches (that is, the first associated array), or nil if no match is found. See also Array#rassoc.
    # like value=values.assoc(attribute_from_database)[1] (the [1] is needed since the result of #assoc = [1,'v'] and we need the 'v')
    # I feel it's ugly but it works.
    # 2012-02-09 Use Case slider_with_values
    # { 0 => '???', 1 => '--', 2 => '-', 3 => '+-', 4 => '+', 5 => '++' }
    # In the dropdown (or the slider) we definately need the order preserverd.
    # attribulte_values turns this into
    # [ [0,'???'], [1, '--'] .... [5, '++'] ]
    #
    # Row shape (since 8.1.x): [ :attr, :form_element, values, options_disabled ].
    # `values` lives at index 2 (was index 3 before the empty label string was
    # dropped in 8.1.x).

    attributes = @inline_forms_attribute_list || object.inline_forms_attribute_list # if we do this as a form_element, @inline.. is nil!!!
    values = attributes.assoc(attribute.to_sym)[2]
    # (was `raise t("fatal.no_values_defined_in", @Klass, attribute)` — Rails'
    # translate takes a key plus keyword interpolations, so the raise itself
    # crashed with ArgumentError instead of reporting the real problem.)
    raise "inline_forms: no values defined in #{object.class} for #{attribute} (add a values hash to the inline_forms_attribute_list row)" if values.nil?
    if values.is_a?(Hash)
      temp = Array.new
      values.to_a.each do |k, v|
        temp << [ k, inline_forms_value_label(v) ]
      end
      values = inline_forms_sort_values(temp) { |pair| pair[0] }
    else
      temp = Array.new
      values.to_a.each_index do |i|
        temp << [ i, inline_forms_value_label(values.to_a[i]) ]
      end
      values = inline_forms_sort_values(temp) { |pair| pair[1] }
    end
    values
  end

  # nil first (a blank option), then numbers in numeric order, then anything
  # else as text, equal ones in their given order. One key for every value: a pairwise fallback
  # ((a <=> b) || (a.to_s <=> b.to_s), 8.1.85) contradicted itself on a mixed
  # list ([10, 9, "1a"] put 10 before 9). A list that mixes numbers and
  # strings ([1, 2, "many"]) raised ArgumentError in 8.1.83, once labels
  # stopped being the strings t() returned.
  def inline_forms_sort_values(pairs)
    pairs.each_with_index.sort_by { |pair, index| [ inline_forms_value_sort_key(yield(pair)), index ] }.map(&:first)
  end

  def inline_forms_value_sort_key(value)
    if value.nil? then [ 0, 0, "" ]
    elsif value.is_a?(Numeric) && value.real? then [ 1, value, "" ]
    else [ 2, 0, value.to_s ]
    end
  end

  # A value as text for the screen: a Date as dd-mm-yyyy (since Rails 7.1 a
  # bare Date prints ISO), a time as inline_forms_time_text, anything else
  # as it is. Used by the info elements and the versions panel.
  def inline_forms_value_text(value)
    case value
    when DateTime, Time, ActiveSupport::TimeWithZone then inline_forms_time_text(value)
    when Date then value.strftime(InlineForms::DATE_FORMAT)
    else value
    end
  end

  # A version or file timestamp: the date with its year
  # (time.formats.inline_forms; rails-i18n's :short has none, so edits years
  # apart read the same), the exact ISO 8601 time on hover.
  def inline_forms_time(time)
    tag.time(inline_forms_time_text(time), datetime: time.iso8601, title: time.iso8601)
  end

  # The text alone. The gem defines time.formats.inline_forms only in en and
  # nl; in another locale without it (and without i18n fallbacks) a bare
  # l(format: :inline_forms) raises, so the same format is the default. The
  # month names still come from that locale (rails-i18n).
  def inline_forms_time_text(time)
    l(time, format: :inline_forms, default: InlineForms::TIME_FORMAT)
  end

  # The application's name for the gem's titles and the Devise pages
  # (InlineForms.application_title).
  def inline_forms_application_title
    InlineForms.application_title
  end

  # An update version that changed nothing (a `touch`, a callback): the
  # versions panel hides its Restore link. Only when the versions table
  # records changes at all: without an object_changes column every changeset
  # is empty, and Restore (which reifies `object`) must stay.
  def inline_forms_empty_changeset?(version)
    columns = version.class.try(:column_names)
    return false if columns && !columns.include?("object_changes")

    version.changeset.nil? || version.changeset.except("updated_at").empty?
  end

  def version_modified_by(id)
    return "Unknown" if id.blank?

    # Devise keys mappings by the singular scope (`devise_for :users` ->
    # :user); the old `[:users]` lookup never matched, so every name was
    # "Unknown".
    mapping = Devise.mappings[:user] || Devise.mappings[:users] || Devise.mappings.values.first
    user_class = mapping&.to
    return "Unknown" unless user_class

    user = user_class.find_by(id: id)
    user.nil? ? "Unknown" : user.name
  end
end
