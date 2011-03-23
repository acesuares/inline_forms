module InlineFormsHelper

  # load form elements. Each element goes into a separate file
  # and defines a _show, _edit and _update method.
  #
  INLINE_FORMS_PATH = File.dirname(__FILE__) + "/form_elements/"
  Dir[INLINE_FORMS_PATH + "*.rb"].each do |form_element|
    require form_element
  end

  # default inline forms attribute list, for models that don't have an inline_attribute_attribute_list defined.
  INLINE_FORMS_DEFAULT_ATTRIBUTE_LIST = { :name => [ 'name', :text ] }

  # show a record by iterating through its attribute list
  def inline_forms_show_record(object, attributes=nil)
    out = String.new
    name_cell = content_tag :th, :valign=>'top' do
      content_tag :div, :class=> "object_presentation" do
        h(object._presentation)
      end
    end
    value_cell = content_tag :th, :valign=>'top' do
      content_tag :div, :class=> "close_link" do
        close_link(object)
      end
    end
    out += content_tag :tr, name_cell + value_cell
    out << "\n"
    attributes ||= object.inline_forms_attribute_list
    attributes.each do | attribute, name, form_element |
      css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
      name_cell = content_tag :td, :valign=>'top' do
        content_tag :div, :class=> "attribute_name attribute_#{attribute} form_element_#{form_element}" do
          h(name)
        end
      end
      value_cell = content_tag :td, :valign=>'top' do
        content_tag :div, :class=> "attribute_value attribute_#{attribute} form_element_#{form_element}" do
          content_tag :span, :id => css_class_id do
            if form_element == :associated
              inline_forms_list(object.send(attribute.to_s.pluralize), attribute )
            else
              send("#{form_element}_show", object, attribute)
            end
          end
        end
      end
      out += content_tag :tr, name_cell + value_cell
      out += "\n"
    end
    #    end
    return content_tag :table, raw(out), :cellspacing => 0, :cellpadding => 0
  end

  # show the form for a new record
  #
  # associated records are NOT shown!
  #
  def inline_forms_new_record(object, attributes=nil)
    out = String.new
    out += content_tag :tr do
      content_tag :th, :colspan => 2, :valign=>'top' do
        content_tag :div, :class=> "object_presentation" do
          "New #{object.class.to_s}"
        end
      end
    end
    out << "\n"
    attributes ||= object.inline_forms_attribute_list
    attributes.each do | attribute, name, form_element |
      unless form_element.to_sym == :associated
        css_class_id = "attribute_#{attribute}_#{object.id}"
        name_cell = content_tag :td, :valign=>'top' do
          content_tag :div, :class=> "attribute_name attribute_#{attribute} form_element_#{form_element}" do
            h(name)
          end
        end
        value_cell = content_tag :td, :valign=>'top' do
          content_tag :div, :class=> "attribute_value attribute_#{attribute} form_element_#{form_element}" do
            content_tag :span, :id => css_class_id do
              send("#{form_element}_edit", object, attribute)
            end
          end
        end
        out += content_tag :tr, name_cell + value_cell
      end
    end
    return content_tag :table, raw(out), :cellspacing => 0, :cellpadding => 0
  end

  # display a list of objects
  def inline_forms_list(objects, attribute )
    t = String.new
    # link to new
    update_span = attribute.to_s.underscore + '_list'
    t += content_tag :li, :class => "new_record_link_li" do
      link_to "New",
        send('new_' + attribute.to_s.singularize.underscore + '_path', :update => update_span),
        :remote => true
    end
    # list of objects
    objects.each do |object|
      css_class_id = object.class.to_s.underscore + '_' + object.id.to_s
      t += content_tag :li, :id => css_class_id, :class => cycle("odd", "even") do
        link_to h(object._presentation),
          send( object.class.to_s.underscore + '_path', object, :update => css_class_id),
          :remote => true
      end
    end
    t = content_tag :ul, :id => update_span, :class => "inline_forms_list" do
      t.html_safe
    end
    return t
  end

  private

  # close icon
  def close_link( object )
    link_to image_tag(  'css/close.png',
      :class => "close_icon" ),
      send( object.class.to_s.underscore + '_path',
      object,
      :update => object.class.to_s.underscore + '_' + object.id.to_s,
      :close => true ),
      :remote => true
  end

  # link_to_inline_edit
  def link_to_inline_edit(object, attribute, attribute_value='')
    attribute_value = h(attribute_value)
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    attribute_value << "&nbsp;".html_safe * spaces
    css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
    link_to attribute_value,
      send( 'edit_' + object.class.to_s.underscore + '_path',
      object,
      :attribute => attribute.to_s,
      :form_element => calling_method.sub(/_[a-z]+$/,''),
      :update => css_class_id ),
      :remote => true
  end

  # link to inline image edit
  def link_to_inline_image_edit(object, attribute)
    text= image_tag object.send(attribute).send('url', :thumb)
    link_to text,
      send('edit_' + @Klass.to_s.underscore + '_path',
      object,
      :attribute => attribute.to_s,
      :form_element => calling_method.sub(/_[a-z]+$/,''),
      :update => "attribute_#{attribute}_#{object.id}" ),
      :remote => true
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
    values = object.inline_forms_attribute_list.assoc(attribute.to_sym)[3]
    raise "No Values defined in #{@Klass}, #{attribute}" if values.nil?
    unless values.is_a?(Hash)
      temp = Array.new
      values.to_a.each_index do |i|
        temp << [ i, values.to_a[i] ]
      end
      values = temp.sort {|a,b| a[1]<=>b[1]}
    end
    values
  end

end

# make the current method and the calling method available
#   http://www.ruby-forum.com/topic/75258
#   supposedly, this is fixed in 1.9
module Kernel
  private
  def this_method
    caller[0] =~ /`([^']*)'/ and $1
  end
  def calling_method
    caller[1] =~ /`([^']*)'/ and $1
  end
end

