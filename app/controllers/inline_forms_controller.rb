# == Generic controller for the inline_forms plugin.
# === Usage
# If you have an Example class, make an ExampleController
# that is a subclass of InlineFormsController
#  class ExampleController < InlineFormsController
#  end
# That's it! It'll work. But please read about the InlineForms::InlineFormsGenerator first!
#
# You can override the methods in your ExampleController
#  def index
#    @objects=@Klass.all
#  end
#
#
# @objects holds the objects (in this case Examples)
# and @Klass will be set to Example by the getKlass before filter.
# 
# === How it works
# The getKlass before_filter extracts the class and puts it in @Klass
#
# @Klass is used in the InlineFormsHelper
#
class InlineFormsController < ApplicationController
  before_filter :getKlass
  include InlineFormsHelper

  # shows a list of all objects from class @Klass, using will_paginate
  #
  # The link to 'new' allows you to create a new record.
  #
  def index
    @objects = @Klass.paginate :page => params[:page], :order => 'created_at DESC'
    update_span = params[:update]
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.html { render 'inline_forms/index', :layout => 'inline_forms' }
      format.js { render(:update) {|page| page.replace_html update_span, :partial => 'inline_forms/index' } }
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
    #@values = params[@Klass.to_s.downcase].is_a?(Array) ? params[@Klass.to_s.downcase][@field.to_sym] : nil
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
      @values = params[:values]
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
  # Get the class from the controller name.
  def getKlass #:doc:
    @Klass = self.controller_name.classify.constantize
  end
end
