module InlineFormsHelper
  # associated
  def associated_show(object, attribute, values)
    #show a list of records
    out = ""
    if @sub_id && @sub_id.to_i > 0
      # if it's not a new record (sub_id > 0) then just update the list-element
      out << '<li>'
      out << link_to( @associated_record.title,
        send('edit_' + @Klass.to_s.underscore + '_path', object,
          :field => attribute,
          :sub_id => @sub_id,
          :form_element => this_method.reverse.sub(/.*_/,'').reverse,
          :values => values,
          :update => "field_#{attribute.singularize}_#{@sub_id.to_s}" ),
        :method => :get,
        :remote => true )
      out << '</li>'
    else
      # if it's a new record (sub_id == 0) then update the whole <ul> and redraw all list-elements
      out << "<ul class='associated #{attribute}' id='list_#{attribute}_#{object.id.to_s}'>" if @sub_id.nil?
      if not object.send(attribute.pluralize).empty?
        # if there are things to show, show them
        object.send(attribute.pluralize).each do |m|
          out << "<span id='field_#{attribute.singularize}_#{m.id.to_s}'>"
          out << '<li>'
          out << link_to( m.title, send('edit_' + @Klass.to_s.underscore + '_path',
              object,
              :field => attribute,
              :sub_id => m.id,
              :form_element => this_method.sub(/_[a-z]+$/,''),
              :values => values,
              :update => "field_#{attribute.singularize}_#{m.id.to_s}" ),
            :method => :get,
            :remote => true )
          out << '</li>'
          out << '</span>'
        end
      end
      # add a 'new' link for creating a new record
      out << '<li>'
      out << link_to( 'new', send('edit_' + @Klass.to_s.underscore + '_path',
          object,
          :field => attribute,
          :sub_id => 0,
          :form_element => this_method.sub(/_[a-z]+$/,''),
          :values => values,
          :update => "list_#{attribute}_#{object.id.to_s}" ),
        :method => :get,
        :remote => true )
      out << '</li>'
      out << '</ul>' if @sub_id.nil?
    end
    raw(out)
  end
  def associated_edit(object, attribute, values)
    # @sub_id is the id of the associated record
    if @sub_id.to_i > 0
      # only if @sub_id > 0, means we have a associated record
      @associated_record_id = object.send(attribute.singularize + "_ids").index(@sub_id.to_i)
      @associated_record = object.send(attribute)[@associated_record_id]
      @update_span = "field_#{attribute.singularize}_#{@sub_id.to_s}"
    else
      # but if @sub_id = 0, then we are dealing with a new associated record
      # in that case, we .new a record, and the update_span is the whole <ul>
      @associated_record = attribute.singularize.capitalize.constantize.new
      @update_span = 'list_' + attribute.to_s + '_' + object.id.to_s
    end
    render :partial => "inline_forms/subform"
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
      @update_span = 'list_' + attribute.to_s + '_' + object.id.to_s
    end
    # process the sub_form fields (attributes). These are declared in the model!
    @associated_record.inline_forms_field_list.each do | @subform_description, @subform_field, @subform_element |
      # have no fear
      send("#{@subform_element}_update", @associated_record, @subform_field, nil)
    end
    @associated_record.save
  end
end

