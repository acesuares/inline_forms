module InlineFormsHelper

  # load form elements. Each element goes into a separate file
  # and defines a _show, _edit and _update method.
  #
  INLINE_FORMS_PATH = File.dirname(__FILE__) + "/form_elements/"
  Dir[INLINE_FORMS_PATH + "*.rb"].each do |form_element|
    require form_element
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

