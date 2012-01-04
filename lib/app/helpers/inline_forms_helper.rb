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

  # close link
  def close_link( object, update_span )
    link_to image_tag(  'close.png',
      :class => "close_icon",
      :title => 'close' ),
      send( object.class.to_s.underscore + '_path',
      object,
      :update => update_span,
      :close => true ),
      :remote => true
  end

  # destroy link
  def link_to_destroy( msg, object, update_span )
    if cancan_disabled? || ( can? :destroy, object )
      link_to image_tag(  'trash.png',
        :class => "trash_icon",
        :title => 'trash' ),
        send( object.class.to_s.underscore + '_path',
        object,
        :update => update_span ),
        :method => :delete,
        :remote => true
    end
  end

  def link_to_undo_destroy(msg, object, update_span )
    link_to("undo", revert_version_path(object.versions.scoped.last), :method => :post)
  end



  # link_to_inline_edit
  def link_to_inline_edit(object, attribute, attribute_value='')
    attribute_value = h(attribute_value)
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    attribute_value << "&nbsp;".html_safe * spaces
    css_class_id = "#{object.class.to_s.underscore}_#{object.id}_#{attribute}"
    if cancan_disabled? || ( can? :update, object )
      link_to attribute_value,
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

  def link_to_new_record(text, model, path_to_new, update_span, parent_class, parent_id)
    out = ""
    out << "<li class='new_record_link'>"
    out << (link_to text, send(path_to_new, :update => update_span, :parent_class => parent_class, :parent_id => parent_id ), :remote => true)
    out << "</li>"
    ""
    if cancan_enabled?
      if can?(:create, model.constantize)
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
    values = object.inline_forms_attribute_list.assoc(attribute.to_sym)[3]
    raise "No Values defined in #{@Klass}, #{attribute}" if values.nil?
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

