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

  def self.cancan_enabled?
    begin
      ::Ability && true
    rescue NameError
      false
    end
  end

  def cancan_enabled?
    self.class.cancan_enabled?
  end

  def cancan_disabled?
    ! self.class.cancan_enabled?
  end

  helper_method :cancan_disabled?, :cancan_enabled?

  load_and_authorize_resource if cancan_enabled?

  include InlineFormsHelper

  # shows a list of all objects from class @Klass, using will_paginate
  #
  # The link to 'new' allows you to create a new record.
  #
  def index
    update_span = params[:update]
    @parent_class = params[:parent_class]
    @parent_id = params[:parent_id]
    @ul_needed = params[:ul_needed]
    @PER_PAGE = 5 unless @parent_class.nil?
    # if the parent_class is not nill, we are in associated list and we don't search there.
    # also, make sure the Model that you want to do a search on has a :name attribute. TODO
    @parent_class.nil? ? conditions = ["name like ?", "%#{params[:search]}%" ] : conditions =  [ "#{@parent_class.foreign_key} = ?", @parent_id ]
    if cancan_enabled?
      @objects = @Klass.accessible_by(current_ability).order(@Klass.order_by_clause).paginate :page => params[:page], :per_page => @PER_PAGE || 12, :conditions => conditions
    else
      @objects = @Klass.order(@Klass.order_by_clause).paginate :page => params[:page], :per_page => @PER_PAGE || 12, :conditions => conditions
    end
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.html { render 'inline_forms/_list', :layout => 'inline_forms' } unless @Klass.not_accessible_through_html?
      format.js { render(:update) {|page| page.replace_html update_span, :partial => 'inline_forms/list' } }
    end
  end

  # :new prepares a new object, updates the entire list of objects and replaces it with a new
  # empty form. After pressing OK or Cancel, the list of objects is retrieved in the same way as :index
  #
  # GET /examples/new
  def new
    @object = @Klass.new
    @update_span = params[:update]
    @parent_class = params[:parent_class]
    unless @parent_class.nil?
      @parent_id = params[:parent_id]
      @object[@parent_class.foreign_key] = @parent_id
    end
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.js { render(:update) {|page| page.replace_html @update_span, :partial => 'inline_forms/new'}
      }
    end
  end

  # :edit presents a form to edit one specific attribute from an object
  #
  # GET /examples/1/edit
  #
  def edit
    @object = @Klass.find(params[:id])
    @attribute = params[:attribute]
    @form_element = params[:form_element]
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
    attributes = object.inline_forms_attribute_list
    attributes.each do | attribute, name, form_element |
      send("#{form_element.to_s}_update", object, attribute) unless form_element == :associated
    end
    @parent_class = params[:parent_class]
    @parent_id = params[:parent_id]
    @PER_PAGE = 5 unless @parent_class.nil?
    # for the logic behind the :conditions see the #index method.
    @parent_class.nil? ? conditions = ["name like ?", "%#{params[:search]}%" ] : conditions =  [ "#{@parent_class.foreign_key} = ?", @parent_id ]
    object[@parent_class.foreign_key] = @parent_id unless @parent_class.nil?
    if object.save
      flash.now[:success] = "Successfully created #{object.class.to_s.underscore}."
      if cancan_enabled?
        @objects = @Klass.accessible_by(current_ability).order(@Klass.order_by_clause).paginate :page => params[:page], :per_page => @PER_PAGE || 12, :conditions => conditions
      else
        @objects = @Klass.order(@Klass.order_by_clause).paginate :page => params[:page], :per_page => @PER_PAGE || 12, :conditions => conditions
      end
      respond_to do |format|
        # found this here: http://www.ruby-forum.com/topic/211467
        format.js { render(:update) {|page| page.replace_html @update_span, :partial => 'inline_forms/list'}
        }
      end
    else
      flash.now[:error] = "Failed to create #{object.class.to_s.underscore}.".html_safe
      object.errors.each do |e|
        flash.now[:error] << '<br />'.html_safe + e[0].to_s + ": " + e[1]
      end
      respond_to do |format|
        @object = object
        format.js { render(:update) {|page| page.replace_html @update_span, :partial => 'inline_forms/new'}
        }
      end
    end
  end
  # :update updates a specific attribute from an object.
  #
  # PUT /examples/1
  #
  def update
    @object = @Klass.find(params[:id])
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    send("#{@form_element.to_s}_update", @object, @attribute)
    @object.save
    respond_to do |format|
      # found this here: http://www.ruby-forum.com/topic/211467
      format.js { render(:update) {|page| page.replace_html @update_span, :inline => '<%= send("#{@form_element.to_s}_show", @object, @attribute) %>' }
      }
    end
  end

  # :show shows one attribute (attribute) from a record (object). It inludes the link to 'edit'
  #
  # GET /examples/1?attribute=name&form_element=text
  #
  
  def show
    @object = @Klass.find(params[:id])
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    close = params[:close] || false
    if @form_element == "associated"
      @sub_id = params[:sub_id]
      if @sub_id.to_i > 0
        @associated_record_id = @object.send(@attribute.to_s.singularize + "_ids").index(@sub_id.to_i)
        @associated_record = @object.send(@attribute)[@associated_record_id]
      end
    end
    @update_span = params[:update]
    if @attribute.nil?
      respond_to do |format|
        @attributes = @object.inline_forms_attribute_list
        # found this here: http://www.ruby-forum.com/topic/211467
        if close
          format.js do
            render(:update) do |page|
              page.replace_html @update_span, :inline => '<%= link_to h(@object._presentation), send(@object.class.to_s.underscore + "_path", @object, :update => @update_span), :remote => true %>'
            end
          end
        else
          format.js do
            render(:update) do |page|
              page.replace_html @update_span, :partial => 'inline_forms/show'
            end
          end
          #          format.js { render(:update) {|page| page.replace_html @update_span, :inline => '<%= send( "inline_forms_show_record", @object) %>' } }
        end
      end
    else
      respond_to do |format|
        # found this here: http://www.ruby-forum.com/topic/211467
        format.js do
          render(:update) do |page|
            page.replace_html @update_span, :inline => '<%= send("#{@form_element}_show", @object, @attribute) %>'
          end
        end
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
