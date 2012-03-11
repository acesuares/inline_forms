module InlineFormsHelper
  # load form elements. Each element goes into a separate file
  # and defines a _show, _edit and _update method.
  #
  INLINE_FORMS_PATH = File.dirname(__FILE__) + "/form_elements/"
  Dir[INLINE_FORMS_PATH + "*.rb"].each do |form_element|
    require form_element
  end

  private

  def inline_forms_version
    InlineForms::VERSION
  end

  # used as class name
  def has_validations(object, attribute)
    "has_validations " unless object.class.validators_on(attribute).empty?
  end

  def validation_help_as_list_for(object, attribute)
    "" and return if object.class.validators_on(attribute).empty?
    content_tag(:ul, validation_help_for(object, attribute).map { |help_message| content_tag(:li, help_message ) }.to_s.html_safe )
  end

  # validation_help_for(object, attribute) extracts the help messages for
  # attribute of object.class (in an Array)
  def validation_help_for(object, attribute)
    "" and return if object.class.validators_on(attribute).empty?
    object.class.validators_on(attribute).map do |v|
      t("inline_forms.validators.help.#{ActiveModel::Name.new(v.class).i18n_key.to_s.gsub(/active_model\/validations\//, '')}")
    end.compact
  end

  # close link
  def close_link( object, update_span )
    link_to image_tag(  'close.png',
      :class => "close_icon",
      :title => t('inline_forms.view.close') ),
      send( object.class.to_s.underscore + '_path',
      object,
      :update => update_span,
      :close => true ),
      :remote => true
  end

  # destroy link
  def link_to_destroy( object, update_span )
    if cancan_disabled? || ( can? :destroy, object )
      link_to image_tag(  'trash.png',
        :class => "trash_icon",
        :title => t('inline_forms.view.trash') ),
        send( object.class.to_s.underscore + '_path',
        object,
        :update => update_span ),
        :method => :delete,
        :remote => true
    end
  end

#  # undo link
#  def link_to_undo_destroy(object, update_span )
#    link_to(t('inline_forms.view.undo'), revert_version_path(object.versions.scoped.last), :method => :post)
#  end

  # link_to_inline_edit
  def link_to_inline_edit(object, attribute, attribute_value='')
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    attribute_value << "&nbsp;".html_safe * spaces
    css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
    if cancan_disabled? || ( can? :update, object )
      link_to attribute_value.html_safe,
        send( 'edit_' + object.class.to_s.underscore + '_path',
        object,
        :attribute => attribute.to_s,
        :form_element => calling_method.sub(/_[a-z]+$/,''),
        :update => css_class_id ),
        :remote => true
    else
      attribute_value
    end
  end

  # link to new record
  def link_to_new_record(model, path_to_new, update_span, parent_class, parent_id)
    out = ""
    out << "<li class='new_record_link'>"
    out << (link_to image_tag(  'add.png',
        :class => "new_record_icon",
        :title => t('inline_forms.view.add_new', :model => model.model_name.human ) ),
      send(path_to_new, :update => update_span, :parent_class => parent_class, :parent_id => parent_id ),
      :remote => true)
    out << "<div style='clear: both;'></div>"
    out << "</li>"
    ""
    if cancan_enabled?
      if can?(:create, model)
        if parent_class.nil?
          raw out
        else
          raw out if can?(:update, parent_class.find(parent_id))
        end
      end
    else
      raw out
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
        temp << [ k, v ]
      end
      values = temp.sort {|a,b| a[0]<=>b[0]}
    else
      temp = Array.new
      values.to_a.each_index do |i|
        temp << [ i, values.to_a[i] ]
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

