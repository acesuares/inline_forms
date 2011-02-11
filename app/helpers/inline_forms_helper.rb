INLINE_FORMS_PATH = File.dirname(__FILE__) + "/form_elements/"

Dir[INLINE_FORMS_PATH + "*.rb"].each do |form_element|
  require form_element
end

module InlineFormsHelper
  def inline_form(object, attributes) #, collapsed=true)
    attributes = [ attributes ] if not attributes[0].is_a?(Array) # make sure we have an array of arrays
    out = String.new #ugly as hell but that's how content_tag works...
#    if collapsed
#      then
#      name_cell = content_tag :td, :valign=>'top' do
#        content_tag :div, :class=> "field_name" do
#          h(object.presentation)
#        end
#      end
#      value_cell = content_tag :td, :valign=>'top' do
#        content_tag :div, :class=> "field_value" do
#          link_to 'edit', send( @Klass.to_s.underscore + '_path', object, :update => 'inline_form_list'), :remote => true
#        end
#      end
#      out += content_tag :tr, name_cell + value_cell
#      out += "\n"
#    else
      attributes.each do | attribute, name, form_element, values |
        #css_class_id = form_element == :associated ? "subform_#{attribute.to_s}_#{object.id}" : "field_#{attribute.to_s}_#{object.id}"
        css_class_id = "field_#{attribute.to_s}_#{object.id}"
        name_cell = content_tag :td, :valign=>'top' do
          content_tag :div, :class=> "field_name field_#{attribute.to_s} form_element_#{form_element.to_s}" do
            h(name)
          end
        end
        value_cell = content_tag :td, :valign=>'top' do
          content_tag :div, :class=> "field_value field_#{attribute.to_s} form_element_#{form_element.to_s}" do
            content_tag :span, :id => css_class_id do
              send("#{form_element.to_s}_show", object, attribute, values)
            end
          end
        end
        out += content_tag :tr, name_cell + value_cell
        out += "\n"
      end
#    end
    return content_tag :table, raw(out), :cellspacing => 0, :cellpadding => 0
  end

  def inline_form_display_new(object, attributes)
    attributes = [ attributes ] if not attributes[0].is_a?(Array) # make sure we have an array of arrays
    out = String.new #ugly as hell but that's how content_tag works...
    attributes.each do | attribute, name, form_element, values |
      #css_class_id = form_element == :associated ? "subform_#{attribute.to_s}_#{object.id}" : "field_#{attribute.to_s}_#{object.id}"
      if not form_element.to_sym == :associated
        css_class_id = "field_#{attribute.to_s}_#{object.id}"
        name_cell = content_tag :td, :valign=>'top' do
          content_tag :div, :class=> "field_name field_#{attribute.to_s} form_element_#{form_element.to_s}" do
            h(name)
          end
        end
        value_cell = content_tag :td, :valign=>'top' do
          content_tag :div, :class=> "field_value field_#{attribute.to_s} form_element_#{form_element.to_s}" do
            content_tag :span, :id => css_class_id do
              send("#{form_element.to_s}_edit", object, attribute, values)
            end
          end
        end
        out += content_tag :tr, name_cell + value_cell
      end
    end
    return content_tag :table, raw(out), :cellspacing => 0, :cellpadding => 0
  end
  # display a list of objects
  def inline_form_display_list(objects, tag=:li)
    t = ''
    objects.each do |object|
      t += content_tag tag do
        inline_form object, object.respond_to?(:inline_forms_field_list) ? object.inline_forms_field_list : [ :name, 'name', 'text_field' ]
      end
    end
    return raw(t)
  end
  # link for new item
  def inline_form_new_record(attribute, form_element, text='new', update_span='inline_form_list')
    link_to text, send('new_' + @Klass.to_s.underscore + '_path', :update => update_span), :remote => true
  end


  
  private

  # link_to_inline_edit
  def link_to_inline_edit(object, attribute, attribute_value, values)
    attribute_value = h(attribute_value)
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    attribute_value << "&nbsp;".html_safe * spaces
    link_to raw(attribute_value), send('edit_' + @Klass.to_s.underscore + '_path',
      object,
      :field => attribute.to_s,
      :form_element => calling_method.sub(/_[a-z]+$/,''),
      :values => values,
      :update => 'field_' + attribute.to_s + '_' + object.id.to_s ),
      :remote => true
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

