module InlineFormHelper
  # display the forms from an array of attributes
  def inline_form_display(object, attributes, action=:show)
    attributes = [ attributes ] if not attributes[0].is_a?(Array) # make sure we have an array of arrays
    out = String.new #ugly as hell but that's how content_tag works...
    case action
    when :show
      attributes.each do | name, attribute, form_element, values |
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
              send("#{form_element.to_s}_#{action}", object, attribute, values)
            end
          end
        end
        out += content_tag :tr, name_cell + value_cell
      end
      return content_tag :table, out, :cellspacing => 0, :cellpadding => 0
    when :new
      attributes.each do | name, attribute, form_element, values |
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
              if not form_element == :associated
                send("#{form_element.to_s}_edit", object, attribute, values)
              else
                #send("#{form_element.to_s}_show", object, attribute, values)
              end
            end
          end
        end
        out += content_tag :tr, name_cell + value_cell
      end
      return content_tag :table, out, :cellspacing => 0, :cellpadding => 0
    end
  end
  # display a list of objects
  def inline_form_display_list(objects, tag=:li)
    t = ''
    objects.each do |object|
      t += content_tag tag do
        inline_form_display object, object.respond_to?(:field_list) ? object.field_list : [ '', :name, :text ]
      end
    end
    return t
  end
  # link for new item
  def inline_form_new_record(attribute, form_element, text='new', update_span='inline_form_list')
    link_to_remote( text,
      :url => {
        :action => :new,
        :controller => @Klass_pluralized,
        :field => attribute,
        :form_element => form_element,
        :update_span => update_span },
      :method => :get,
      :update => update_span )
  end

  # dropdown
  def dropdown_show(object, attribute, values)
    attribute_value = object.send(attribute).presentation rescue  nil
    link_to_inline_edit object, attribute, attribute_value, nil
  end
  def dropdown_edit(object, attribute, values)
    object.send('build_' + attribute.to_s) unless object.send(attribute)
    values = object.send(attribute).class.name.constantize.find(:all, :order => 'name ASC')
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_s.foreign_key.to_sym, values, 'id', 'presentation', :selected => object.send(attribute).id)
  end
  def dropdown_update(object, attribute, values)
    object[attribute.to_s.foreign_key.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_s.foreign_key.to_sym]
  end

  # dropdown_with_values
  def dropdown_with_values_show(object, attribute, values)
    link_to_inline_edit object, attribute, values[object.send(attribute)], values
  end
  def dropdown_with_values_edit(object, attribute, values)
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_sym, values, 'first', 'last', :selected => object.send(attribute))
  end
  def dropdown_with_values_update(object, attribute, values)
    object[attribute.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_sym]
  end

  # range
  def range_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def range_edit(object, attribute, values)
    # the leading underscore is to avoid name conflicts, like 'email' and 'email_type' will result in 'email' and 'email[email_type_id]' in the form!
    collection_select( ('_' + object.class.to_s.downcase).to_sym, attribute.to_sym, values, 'to_i', 'to_s', :selected => object.send(attribute))
  end
  def range_update(object, attribute, values)
    object[attribute.to_sym] = params[('_' + object.class.to_s.downcase).to_sym][attribute.to_sym]
  end

  # date
  def date_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def date_edit(object, attribute, values)
    calendar_date_select_tag attribute, object[attribute], :year_range => 30.years.ago..5.years.from_now, :popup => :force
  end
  def date_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end

  # textarea
  def textarea_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def textarea_edit(object, attribute, values)
    text_area_tag attribute, object[attribute], :class => 'field_textarea'
  end
  def textarea_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end

  # text
  def text_show(object, attribute, values)
    link_to_inline_edit object, attribute, object.send(attribute), nil
  end
  def text_edit(object, attribute, values)
    text_field_tag attribute, object[attribute], :class => 'input_text'
  end
  def text_update(object, attribute, values)
    object[attribute.to_sym] = params[attribute.to_sym]
  end

  # bool
  def bool_show(object, attribute, values)
    link_to_inline_edit object, attribute, values[object.send(attribute).to_s], values
  end
  def bool_edit(object, attribute, values)
    collection_select( object.class.to_s.downcase, attribute, values, 'first', 'last', :selected => object.send(attribute).to_s)
  end
  def bool_update(object, attribute, values)
    object[attribute.to_s.to_sym] = params[object.class.to_s.downcase.to_sym][attribute.to_s.to_sym]
  end

  # checklist
  def checklist_show(object, attribute, values)
    out = '<ul class="checklist">'
    out << link_to_inline_edit(object, attribute, nil, nil) if object.send(attribute).empty?
    object.send(attribute).sort.each do | item |
      out << '<li>'
      out << link_to_inline_edit(object, attribute, item.title, nil)
      out << '</li>'
    end
    out <<  '</ul>'
  end
  def checklist_edit(object, attribute, values)
    object.send(attribute).build  if object.send(attribute).empty?
    values = object.send(attribute).first.class.name.constantize.find(:all, :order => "name ASC")
    out = '<div class="edit_form_checklist">'
    out << '<ul>'
    values.each do | item |
      out << '<li>'
      out << check_box_tag( attribute + '[' + item.id.to_s + ']', 'yes', object.send(attribute.singularize + "_ids").include?(item.id) )
      out << '<div class="edit_form_checklist_text">'
      out << h(item.title)
      out << '</div>'
      out << '<div style="clear: both;"></div>'
      out << '</li>'
    end
    out << '</ul>'
    out << '</div>'
  end
  def checklist_update(object, attribute, values)
    params[attribute] ||= {}
    object.send(attribute.singularize + '_ids=', params[attribute].keys)
  end

  # associated
  def associated_show(object, attribute, values)
    #show a list of records
    out = ""
    if @sub_id && @sub_id.to_i > 0
      # if it's not a new record (sub_id > 0) then just update the list-element
      out << '<li>'
      out << link_to_remote( @associated_record.title,
        :url => { :action => 'edit',
          :id => object.id,
          :field => attribute,
          :sub_id => @sub_id,
          :form_element => this_method.reverse.sub(/.*_/,'').reverse,
          :values => values },
        :method => :get,
        :update => "field_#{attribute.singularize}_#{@sub_id.to_s}" )
      out << '</li>'
    else
      # if it's a new record (sub_id == 0) then update the whole <ul> and redraw all list-elements
      out << "<ul class='associated #{attribute}' id='list_#{attribute}_#{object.id.to_s}'>" if @sub_id.nil?
      if not object.send(attribute.pluralize).empty?
        # if there are things to show, show them
        object.send(attribute.pluralize).each do |m|
          out << "<span id='field_#{attribute.singularize}_#{m.id.to_s}'>"
          out << '<li>'
          out << link_to_remote( m.title,
            :url => { :action => 'edit',
              :id => object.id,
              :field => attribute,
              :sub_id => m.id,
              :form_element => this_method.sub(/_[a-z]+$/,''),
              :values => values },
            :method => :get,
            :update => "field_#{attribute.singularize}_#{m.id.to_s}" )
          out << '</li>'
          out << '</span>'
        end
      end
      # add a 'new' link for creating a new record
      out << '<li>'
      out << link_to_remote( 'new',
        :url => { :action => 'edit',
          :id => object.id,
          :field => attribute,
          :sub_id => 0,
          :form_element => this_method.sub(/_[a-z]+$/,''),
          :values => values },
        :method => :get,
        :update => "list_#{attribute}_#{object.id.to_s}" )
      out << '</li>'
      out << '</ul>' if @sub_id.nil?
    end
    out
  end
  def associated_edit(object, attribute, values)
    # @sub_id is the id of the assoicated record
   if @sub_id.to_i > 0
      # only if @sub_id > 0, means we have a associated record
      @associated_record_id = object.send(attribute.singularize + "_ids").index(@sub_id.to_i)
      @associated_record = object.send(attribute)[@associated_record_id]
      @update_span = "field_#{attribute.singularize}_#{@sub_id.to_s}"
    else
      # but if @sub_id = 0, then we are dealing with a new associated record
      # in that case, we .new a record, and the update_span is the whole <ul>
      @associated_record = attribute.singularize.capitalize.constantize.new
      @update_span = "list_#{attribute}_#{object.id.to_s}"
    end
    render :partial => "subform"
  end
  def associated_update(object, attribute, values)
    return if object.id.nil?
    if @sub_id.to_i > 0
      # get the existing associated record
      @associated_record_id = object.send(attribute.singularize + "_ids").index(@sub_id.to_i)
      @associated_record = object.send(attribute)[@associated_record_id]
      @update_span = "field_" + attribute.singularize + '_' + @sub_id.to_s
    else
      # create a new associated record
      @associated_record = object.send(attribute.to_sym).new
      @update_span = 'list_#{attribute}_#{object.id.to_s}'
    end
    # process the sub_form fields (attributes). These are declared in the model!
    @associated_record.field_list.each do | @subform_description, @subform_field, @subform_element |
      # have no fear
      send("#{@subform_element}_update", @associated_record, @subform_field, nil)
    end
    @associated_record.save
  end

  # geo_code_curacao
  def geo_code_curacao_show(object, attribute, values)
    attribute_value = object.send(attribute).presentation rescue nil
    link_to_inline_edit object, attribute, attribute_value, nil
  end
  def geo_code_curacao_edit(object, attribute, values)
    text_field_with_auto_complete :geo_code_curacao, :street, :skip_style => true
  end
  def geo_code_curacao_update(object, attribute, values)
    # extract the geocode
    geo_code = params[attribute.to_sym][:street].scan(/\d\d\d\d\d\d/).to_s || nil
    object[attribute.to_sym] = GeoCodeCuracao.new(geo_code).valid? ? geo_code : nil
  end

  private

  # link_to_inline_edit
  # Directly call Erb::Util.h because we sometimes call this from the controller!
  # same with link_to_remote. We are using the @template stuff.
  def link_to_inline_edit(object, attribute, attribute_value, values)
   #needed for h() and link_to_remote()
    attribute_value = h(attribute_value)
    spaces = attribute_value.length > 40 ? 0 : 40 - attribute_value.length
    attribute_value << "&nbsp;" * spaces
    if @Klass == 'Index'
    link_to_remote attribute_value,
      :url => "/#{@Klass_pluralized}/edit/#{object.id}?field=#{attribute.to_s}&form_element=#{calling_method.sub(/_[a-z]+$/,'')}&values=#{values}",
      :update => 'field_' + attribute.to_s + '_' + object.id.to_s,
      :method => :get
    else
    link_to_remote attribute_value,
      :url => "/#{@Klass_pluralized}/#{object.id}/edit?field=#{attribute.to_s}&form_element=#{calling_method.sub(/_[a-z]+$/,'')}&values=#{values}",
      :update => 'field_' + attribute.to_s + '_' + object.id.to_s,
      :method => :get

    end
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

