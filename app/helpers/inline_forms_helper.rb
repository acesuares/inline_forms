# -*- encoding : utf-8 -*-
module InlineFormsHelper
  # load form elements. Each element goes into a separate file
  # and defines a _show, _edit and _update method.
  #
  INLINE_FORMS_PATH = File.dirname(__FILE__) + "/form_elements/"
  Dir[INLINE_FORMS_PATH + "*.rb"].each do |form_element|
    require form_element
  end

  def inline_forms_version
    InlineForms::VERSION
  end

  private

  def validation_hints_as_list_for(object, attribute)
    object.has_validations? ? content_tag(:ul, object.hints.full_messages_for(attribute).map { |m| content_tag(:li, m ) }.join.html_safe )  : ""
  end

  # close link
  def close_link( object, update_span, html_class = 'button close_button' )
    link_to "<i class='fi-x'></i>".html_safe,
      send( object.class.to_s.underscore + '_path',
      object,
      :update => update_span,
      :close => true ),
      :remote => true,
      :class => html_class,
      :title => t('inline_forms.view.close')
  end

  # destroy link
  def link_to_destroy( object, update_span )
    if current_user.role? :superadmin
      if cancan_disabled? || ( can? :delete, object )
        link_to "<i class='fi-trash'></i>".html_safe,
          send( object.class.to_s.underscore + '_path',
          object,
          :update => update_span ),
          :method => :delete,
          :remote => true,
          :title => t('inline_forms.view.trash')
      end
    elsif (object.class.safe_deletable? rescue false)
      if object.deleted?     && (cancan_disabled? || ( can? :revert, object ))
        link_to "undelete".html_safe,
          send( 'revert_' + object.class.to_s.underscore + '_path',
          object,
          :update => update_span ),
          :method => :post,
          :remote => true,
          :title => t('inline_forms.view.trash')
      elsif !object.deleted? && (cancan_disabled? || ( can? :delete, object ))
        link_to "<i class='fi-trash'></i>".html_safe,
          send( object.class.to_s.underscore + '_path',
          object,
          :update => update_span ),
          :method => :delete,
          :remote => true,
          :title => t('inline_forms.view.trash')
      end
    end
  end

  # new link
  def link_to_new_record(model, path_to_new, update_span, parent_class = nil, parent_id = nil, html_class = 'button new_button')
    out = (link_to "<i class='fi-plus'></i>".html_safe,
                   send(path_to_new,
                        :update => update_span,
                        :parent_class => parent_class,
                        :parent_id => parent_id,
                       ),
                   :remote => true,
                   :class => html_class,
                   :title => t('inline_forms.view.add_new', :model => model.model_name.human )
          )
    if cancan_enabled?
      if can? :create, model.to_s.pluralize.underscore.to_sym
        if parent_class.nil?
          raw out
        else
          raw out if can? :update, parent_class.find(parent_id) # can update this specific parent object???
        end
      end
    else
      raw out
    end
  end

  # link to versions list
  def link_to_versions_list(path_to_versions_list, object, update_span, html_class = 'button new_button')
    out = (link_to "<i class='fi-list'></i>".html_safe,
                   send(path_to_versions_list,
                        object,
                        :update => update_span,
                       ),
                   :remote => true,
                   :class => html_class,
                   :title => t('inline_forms.view.list_versions')
          )
    if current_user.role? :superadmin
      raw out
    end
  end

  # close versions list link
  def close_versions_list_link(object, update_span, html_class = 'button close_button' )
    link_to "<i class='fi-x'></i>".html_safe,
      send('close_versions_list_' + @object.class.to_s.underscore + "_path",
          object,
          :update => update_span
      ),
      :remote => true,
      :class => html_class,
      :title => t('inline_forms.view.close_versions_list')
  end

  # link_to_inline_edit
  def link_to_inline_edit(object, attribute, attribute_value='')
    attribute_value = attribute_value.to_s
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    value = h(attribute_value) + ("&nbsp;" * spaces).html_safe
    css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
    if cancan_disabled? || ( can? :update, object, attribute )
      link_to value,
        send( 'edit_' + object.class.to_s.underscore + '_path',
        object,
        :attribute => attribute.to_s,
        :form_element => calling_method.sub(/_[a-z]+$/,'').sub(/block in /,''),
        :update => css_class_id ),
        :remote => true
    else
      h(attribute_value)
    end
  end

  # url to other language
  def locale_url(request, locale)
    subdomains = request.subdomains
    # if there are no subdomains, prepend the locale to the domain
    return request.protocol + [ locale, request.domain ].join('.') + request.port_string if subdomains.empty?
    # if there is a subdomain, find out if it's an available locale and strip it
    subdomains.shift if I18n.available_locales.include?(subdomains.first.to_sym)
    # if there are no subdomains, prepend the locale to the domain
    return request.protocol + [ locale, request.domain ].join('.') + request.port_string if subdomains.empty?
    # else return the rest
    request.protocol + [ locale, subdomains.join('.'), request.domain ].join('.') + request.port_string
  end

  def translated_attribute(object,attribute)
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
  def attribute_values(object, attribute)
    # if we have a range 1..6  will result in [[0,1],[1,2],[2,3],...,[5,6]]
    # or range -3..3 will result in [[0,-3],[1,-2],[2,-1],...,[6,3]]
    # if we have an array ['a','d','b'] will result in [[0,'a'],[2,'b'],[1,'d']] (sorted on value)
    # if we have a hash { 0=>'a', 2=>'b', 3=>'d' } will result in [[0,'a'],[2,'b'],[3,'d']] (it will keep the index and sort on the index)
    # TODO work this out better!
    # 2012-01-23 Use Cases
    # [ :sex , "sex", :radio_button, { 1 => 'f', 2 => 'm' } ],
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


    attributes = @inline_forms_attribute_list || object.inline_forms_attribute_list # if we do this as a form_element, @inline.. is nil!!!
    values = attributes.assoc(attribute.to_sym)[3]
    raise t("fatal.no_values_defined_in", @Klass, attribute) if values.nil?
    if values.is_a?(Hash)
      temp = Array.new
      values.to_a.each do |k,v|
        temp << [ k, t(v) ]
      end
      values = temp.sort {|a,b| a[0]<=>b[0]}
    else
      temp = Array.new
      values.to_a.each_index do |i|
        temp << [ i, t(values.to_a[i]) ]
      end
      values = temp.sort {|a,b| a[1]<=>b[1]}
    end
    values
  end


end

module Kernel
  private
  # make the current method available
  #   http://www.ruby-forum.com/topic/75258
  #   supposedly, this is fixed in 1.9
  def this_method
    caller[0] =~ /`([^']*)'/ and $1
  end
  # make the calling method available
  #   http://www.ruby-forum.com/topic/75258
  #   supposedly, this is fixed in 1.9
  def calling_method
    caller[1] =~ /`([^']*)'/ and $1
  end
end
