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
  # the must_be_xhr_request before_filter is supposed to only perform the specific actions
  # if the request is an XhttpRequest. There is not much use permitting the actions outside of
  # the XhttpRequest context (except action => :index). Of course, this is not a security measure.
  before_filter :getKlass
  before_filter :must_be_xhr_request, :except => :index
  include InlineFormsHelper # this might also be included in you application_controller with helper :all but it's not needed
  layout false
  # :index shows a list of all objects from class Klass, with all attribute values linked to the 'edit' action.
  # Each field (attribute) is edited seperately (so you don't edit an entire object!)
  # The link to 'new' allows you to create a new record.
  #
  # GET /examples
  #
  def index
#    nolayout = params[:layout] == 'false' || false
    @objects = @Klass.all
#    render( :layout => nolayout || 'inline_forms' )
render 'inline_forms/inline_forms'
  end

  # :show shows one field (attribute) from a record (object). It inludes the link to 'edit'
  #
  # GET /examples/1?field=name&form_element=text
  #
  def show
    @object = @Klass.constantize.find(params[:id])
    @field = params[:field]
    @form_element = params[:form_element]
    if @form_element == "associated"
      @sub_id = params[:sub_id]
      if @sub_id.to_i > 0
        @associated_record_id = @object.send(@field.singularize + "_ids").index(@sub_id.to_i)
        @associated_record = @object.send(@field)[@associated_record_id]
      end
    end
    render :inline => '<%= send("#{@form_element}_show", @object, @field, @values) %>'
  end

  # :new prepares a new object, updates the entire list of objects and replaces it with a new
  # empty form. After pressing OK or Cancel, the list of objects is retrieved in the same way as :index
  #
  # GET /examples/new
  def new
    @object = @Klass.constantize.new
  end

  # :edit presents a form to edit one specific field from an object
  #
  # GET /examples/1/edit
  #
  def edit
    @object = @Klass.constantize.find(params[:id])
    @field = params[:field]
    @form_element = params[:form_element]
    @values = params[:values]
    @sub_id = params[:sub_id]
  end

  # :create creates the object made with :new. It then presents the list of objects.
  #
  # POST /examples
  #
  def create
    object = @Klass.constantize.new
    attributes = object.respond_to?(:field_list) ? object.field_list : [ '', :name, :text ] # sensible default
    attributes = [ attributes ] if not attributes[0].is_a?(Array) # make sure we have an array of arrays
    attributes.each do | name, attribute, form_element, values |
      send("#{form_element.to_s}_update", object, attribute, values)
    end
    object.save
    @objects = @Klass.constantize.all
    render( :action => :index )
  end

  # :update updates a specific field from an object.
  #
  # PUT /examples/1
  #
  def update
    @object = @Klass.constantize.find(params[:id])
    @field = params[:field]
    @form_element = params[:form_element]
    @values = params[:values]
    @sub_id = params[:sub_id]
    send("#{@form_element.to_s}_update", @object, @field, @values)
    @object.save
    render :inline => '<%= send("#{@form_element.to_s}_show", @object, @field, @values) %>'
  end

  # :destroy is not implemented
  # TODO implement a destroy method
  #
  # DELETE /examples/1
  #
  def destroy
    #    @@Klass.constantize = @Klass.constantize.find(params[:id])
    #    @@Klass.constantize.destroy
    redirect_to(@Klass.constantizes_url)
  end

  private
  # If it's not an XhttpRequest, redirect to the index page for this controller.
  #
  # Used in before_filter as a way to limit access to all actions (except :index)
  def must_be_xhr_request #:doc:
    redirect_to "/#{@Klass_pluralized}" if not request.xhr?
  end

  # Get the class
  # Used in before_filter
  def getKlass #:doc:
    @Klass = self.controller_name.classify.constantize
    #request.request_uri.split(/[\/?]/)[1].classify
    #@Klass_constantized = @Klass.constantize
    #@Klass_underscored = @Klass.underscore
    #@Klass_pluralized  = @Klass_underscored.pluralize
  end
end
