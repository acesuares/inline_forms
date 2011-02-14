class InlineFormsController < ApplicationController
  #unloadable # see http://dev.rubyonrails.org/ticket/6001
  # == Generic controller for the inline_forms plugin.
  # === Usage
  # If you have an Example class, make an ExampleController that is a subclass of InlineFormsController
  # <tt>class ExampleController < InlineFormsController
  # # add before filters if you want: before_filter :authenticate_user!, :only => :token
  # # override methods or make your own, using @Klass instead of Example.
  # #  def index
  # #   @objects=@Klass.all
  # #  end
  # === How it works
  # The getKlass before_filter extracts the class and puts it in @Klass
  # === Limited Access
  before_filter :getKlass
  include InlineFormsHelper # this might also be included in you application_controller with helper :all but it's not needed
  # :index shows a list of all objects from class Klass, with all attribute values linked to the 'edit' action.
  # Each field (attribute) is edited seperately (so you don't edit an entire object!)
  # The link to 'new' allows you to create a new record.
  #
  # GET /examples
  #
  def index
    @objects = @Klass.all
    update_span = params[:update]
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.html { render 'inline_forms/index', :layout => 'inline_forms' }
      format.js { render(:update) {|page| page.replace_html update_span, :partial => 'inline_forms/index' }
      }
    end
  end

  

  # :new prepares a new object, updates the entire list of objects and replaces it with a new
  # empty form. After pressing OK or Cancel, the list of objects is retrieved in the same way as :index
  #
  # GET /examples/new
  def new
    @object = @Klass.new
    @update_span = params[:update]
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.js { render(:update) {|page| page.replace_html @update_span, :partial => 'inline_forms/new'}
      }
    end
  end

  # :edit presents a form to edit one specific field from an object
  #
  # GET /examples/1/edit
  #
  def edit
    @object = @Klass.find(params[:id])
    @field = params[:field]
    @form_element = params[:form_element]
    @values = params[:values]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.js { render(:update) {|page| page.replace_html @update_span, :partial => 'inline_forms/edit'}
      }
    end
  end

  # :create creates the object made with :new. It then presents the list of objects.
  #
  # POST /examples
  #
  def create
    object = @Klass.new
    @update_span = params[:update]
    attributes = object.respond_to?(:inline_forms_field_list) ? object.inline_forms_field_list : [ '', :name, :text ] # sensible default
    attributes = [ attributes ] if not attributes[0].is_a?(Array) # make sure we have an array of arrays
    attributes.each do | name, attribute, form_element, values |
      send("#{form_element.to_s}_update", object, attribute, values)
    end
    object.save
    @objects = @Klass.all
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.js { render(:update) {|page| page.replace_html @update_span, :partial => 'inline_forms/index'}
      }
    end
  end
  # :update updates a specific field from an object.
  #
  # PUT /examples/1
  #
  def update
    @object = @Klass.find(params[:id])
    @field = params[:field]
    @form_element = params[:form_element]
    @values = params[:values]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    send("#{@form_element.to_s}_update", @object, @field, @values)
    @object.save
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.js { render(:update) {|page| page.replace_html @update_span, :inline => '<%= send("#{@form_element.to_s}_show", @object, @field, @values) %>' }
      }
    end
  end

  # :show shows one field (attribute) from a record (object). It inludes the link to 'edit'
  #
  # GET /examples/1?field=name&form_element=text
  #
  
  def show
    @object = @Klass.find(params[:id])
    @field = params[:field]
    @form_element = params[:form_element]
    if @form_element == "associated"
      @sub_id = params[:sub_id]
      if @sub_id.to_i > 0
        @associated_record_id = @object.send(@field.to_s.singularize + "_ids").index(@sub_id.to_i)
        @associated_record = @object.send(@field)[@associated_record_id]
      end
    end
    @update_span = params[:update]
    if @field.nil?
      respond_to do |format|
        @attributes = @object.respond_to?(:inline_forms_field_list) ? @object.inline_forms_field_list : [ :name, 'name', 'text_field' ]
        # found this here: http://www.ruby-forum.com/topic/211467
        format.js { render(:update) {|page| page.replace_html @update_span, :inline => '<%= send( "inline_forms_show_record", @object, @attributes) %>' }
        }
      end
    else
      respond_to do |format|
        # found this here: http://www.ruby-forum.com/topic/211467
        format.js { render(:update) {|page| page.replace_html @update_span, :inline => '<%= send("#{@form_element}_show", @object, @field, @values) %>' }
        }
      end
    end
  end

  # :destroy is not implemented
  # TODO implement a destroy method
  #
  # DELETE /examples/1
  #
  #  def destroy
  #    #    @@Klass.constantize = @Klass.constantize.find(params[:id])
  #    #    @@Klass.constantize.destroy
  #    redirect_to(@Klass.constantizes_url)
  #  end

  private
  # Get the class
  # Used in before_filter
  def getKlass #:doc:
    @Klass = self.controller_name.classify.constantize
  end
end
