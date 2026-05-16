# -*- encoding : utf-8 -*-
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
# The getKlass before_action extracts the class and puts it in @Klass
#
# @Klass is used in the InlineFormsHelper
#
class InlineFormsController < ApplicationController
  include CancanConcern
  include VersionsConcern

  before_action :getKlass

  load_and_authorize_resource :except => :revert, :no_params => true if cancan_enabled?
  # :index shows a list of all objects from class @Klass, using will_paginate,
  # including a link to 'new', that allows you to create a new record.
  def index
    @update_span = params[:update]
    @parent_class = params[:parent_class]
    @parent_id = params[:parent_id]
    @ul_needed = params[:ul_needed]
    # if the parent_class is not nill, we are in associated list and we don't search there.
    # also, make sure the Model that you want to do a search on has a :name attribute. TODO
    conditions = nil
    if @parent_class.nil? || @Klass.reflect_on_association(@parent_class.underscore.to_sym).nil?
      conditions = [ @Klass.table_name + "." + @Klass.order_by_clause + " like ?", "%#{params[:search]}%" ] if @Klass.respond_to?(:order_by_clause) && ! @Klass.order_by_clause.nil?
    else
      foreign_key = @Klass.reflect_on_association(@parent_class.underscore.to_sym).options[:foreign_key] || @parent_class.foreign_key
      conditions =  [ "#{foreign_key} = ?", @parent_id ]
    end
    # if we are using cancan, then make sure to select only accessible records
    @objects ||= @Klass.accessible_by(current_ability) if cancan_enabled?
    @objects ||= @Klass
    @objects = @objects.order(@Klass.table_name + "." + @Klass.order_by_clause) if @Klass.respond_to?(:order_by_clause) && ! @Klass.order_by_clause.nil?
    @objects = @objects.where(conditions).paginate(:page => params[:page])
    respond_to do |format|
      # `not_accessible_through_html?` is about preventing direct top-level
      # HTML CRUD on this resource (e.g. /photos when only Apartment is the
      # public surface). The *nested* HTML render -- where `parent_class`
      # was supplied and the response is destined for a parent page's
      # `<turbo-frame>` -- is gated by the parent already (and by cancan
      # above), so we still serve it.
      #
      # Layout choice (was `layout: false` in 7.2.0):
      # - Turbo frame requests (`Turbo-Frame` header) use
      #   `turbo_rails/frame` — minimal `<html><body>` wrapper so the
      #   response parses as a document (turbo-rails default; see
      #   Turbo::Frames::FrameRequest). A bare fragment from `layout: false`
      #   is supposed to work but has been brittle for some clients; the
      #   gem layout is the supported path.
      # - Full-page visits (user opens /photos?... in the tab, or any
      #   navigation without the header) use `inline_forms` so the page is
      #   styled and bootstrapped instead of a naked `<turbo-frame>`.
      #   Turbo still extracts the matching frame when the request *is*
      #   a frame visit, regardless of outer layout (turbo-rails README).
      if @Klass.not_accessible_through_html?
        format.html do
          if @parent_class.present?
            frame_layout = turbo_frame_request? ? "turbo_rails/frame" : "inline_forms"
            render "inline_forms/_list", layout: frame_layout
          end
        end
      else
        format.html { render 'inline_forms/_list', :layout => 'inline_forms' }
      end
      format.js { render :list }
    end
  end

  # :new prepares a new object, updates the list of objects and replaces it with
  # an empty form. After pressing OK or Cancel, the list of objects is retrieved
  # in the same way as :index
  def new
    @object ||= @Klass.new
    @update_span = params[:update]
    @parent_class = params[:parent_class]
    begin
      @parent_id = params[:parent_id]
      foreign_key = @Klass.reflect_on_association(@parent_class.underscore.to_sym).options[:foreign_key] || @parent_class.foreign_key
      @object[foreign_key] = @parent_id
    end unless @parent_class.nil? || @Klass.reflect_on_association(@parent_class.underscore.to_sym).nil?

    @object.inline_forms_attribute_list = @inline_forms_attribute_list if @inline_forms_attribute_list
    respond_to do |format|
      format.html { render 'inline_forms/_new', :layout => 'inline_forms' } unless @Klass.not_accessible_through_html?
      format.js { }
    end
  end

  # :edit presents a form to edit one specific attribute from an object
  def edit
    @object = referenced_object
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    respond_to do |format|
      format.html { render_turbo_field(:field_edit) }
      format.js { }
    end
  end

  # :create creates the object made with :new.
  # It then presents the list of objects.
  def create
    @object ||= @Klass.new
    @update_span = params[:update]
    attributes = @inline_forms_attribute_list || @object.inline_forms_attribute_list
    attributes.each do | attribute, name, form_element |
      InlineForms.assert_plain_text_column!(object: @object, attribute: attribute, form_element: form_element)
      send("#{form_element.to_s}_update", @object, attribute) unless form_element == :tree || form_element == :associated || (cancan_enabled? && cannot?(:read, @object, attribute))
    end
    @parent_class = params[:parent_class]
    @parent_id = params[:parent_id]
    # for the logic behind the :conditions see the #index method.
    conditions = nil
    if @parent_class.nil? || @Klass.reflect_on_association(@parent_class.underscore.to_sym).nil?
      conditions = [ @Klass.table_name + "." + @Klass.order_by_clause + " like ?", "%#{params[:search]}%" ] if @Klass.respond_to?(:order_by_clause) && ! @Klass.order_by_clause.nil?
    else
      foreign_key = @Klass.reflect_on_association(@parent_class.underscore.to_sym).options[:foreign_key] || @parent_class.foreign_key
      conditions =  [ "#{foreign_key} = ?", @parent_id ]
      @object[foreign_key] = @parent_id
    end

    if @object.save
      flash.now[:success] = t('success', :message => @object.class.model_name.human)
      @objects = @Klass
      @objects = @Klass.accessible_by(current_ability) if cancan_enabled?
      @objects = @objects.order(@Klass.table_name + "." + @Klass.order_by_clause) if @Klass.respond_to?(:order_by_clause) && ! @Klass.order_by_clause.nil?
      @objects = @objects.where(conditions).paginate(:page => params[:page])
      @object = nil
      respond_to do |format|
        format.js { render :list}
      end
    else
      flash.now[:header] = ["Kan #{@object.class.to_s.underscore} niet aanmaken."]
      flash.now[:error] = @object.errors.to_a
      respond_to do |format|
        @object.inline_forms_attribute_list = attributes
        format.js { render :new}
      end
    end
  end

  # :update updates a specific attribute from an object.
  def update
    @object = referenced_object
    @attribute = params[:attribute]
    @form_element = params[:form_element]
    @sub_id = params[:sub_id]
    @update_span = params[:update]
    InlineForms.assert_plain_text_column!(object: @object, attribute: @attribute, form_element: @form_element)
    send("#{@form_element.to_s}_update", @object, @attribute)
    @object.save
    respond_to do |format|
      format.html { render_turbo_field(:field_show, turbo_field_show: true) }
      format.js { }
    end
  end

  # :show shows one attribute (attribute) from a record (object).
  # It includes the link to 'edit'
  def show
    @object = referenced_object
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
    if @form_element == "has_one"
      @associated_record = @object.send(@attribute)
      @associated_record_id = @associated_record.id
    end
    @update_span = params[:update]
    if @attribute.nil?
      respond_to do |format|
        @attributes = @object.inline_forms_attribute_list
        if close
          format.html { render_row_turbo(:close) } if row_html_turbo_allowed?
          format.js { render :close }
        else
          format.html { render_row_turbo(:show) } if row_html_turbo_allowed?
          format.js { render :show }
        end
      end
    else
      respond_to do |format|
        format.html { render_turbo_field(:field_show, turbo_field_show: true) }
        format.js { render :show_element }
      end
    end
  end

  # :soft_delete
  def soft_delete
    @update_span = params[:update]
    @object = referenced_object
    # destroy the object
    @object.soft_delete(current_user)
    respond_to do |format|
      format.html { } unless @Klass.not_accessible_through_html?
      format.js { render :close }
    end
  end

  # :soft_restore
  def soft_restore
    @update_span = params[:update]
    @object = referenced_object
    # restore the object
    @object.soft_restore
    respond_to do |format|
      format.html { } unless @Klass.not_accessible_through_html?
      format.js { render :close }
    end
  end

  # :destroy destroys the record. There is no undo!
  def destroy
    @update_span = params[:update]
    @object = referenced_object
    if current_user.role? :superadmin
      # destroy the object
      @undo_object = @object.versions.last
      @object.destroy
      respond_to do |format|
        format.html { } unless @Klass.not_accessible_through_html?
        format.js { render :record_destroyed }
      end
    end
  end

  # :revert works like undo.
  # Thanks Ryan Bates: http://railscasts.com/episodes/255-undo-with-paper-trail
  def revert
    @update_span = params[:update]
    @object = referenced_object
    if current_user.role? :superadmin
      @version = PaperTrail::Version.find(params[:id])
      @version.reify.save!
      @object = @Klass.find(@version.item_id)
      authorize!(:revert, @object) if cancan_enabled?
      respond_to do |format|
        format.html { } unless @Klass.not_accessible_through_html?
        format.js { render :close }
      end
    end
  end

  def extract_translations
    keys_array = []
    I18n::Backend::ActiveRecord::Translation.order(:locale, :thekey).each do |t|
      keys_array << deep_hashify([ t.locale, t.thekey.split('.'), t.value ].flatten)
    end
    keys_hash = {}
    keys_array.each do |h|
      keys_hash = deep_merge(keys_hash, h)
    end
    @display_array = unravel(keys_hash)
  end

  private

  # HTML field edit/show inside a +<turbo-frame>+ (Step 3). Scalar fields no longer
  # use UJS; +format.html+ is always registered for edit/update/single-attribute show.
  def render_turbo_field(template, turbo_field_show: false)
    @turbo_frame = true if template == :field_edit
    @turbo_field_show_turbo_frame = turbo_field_show
    render "inline_forms/#{template}", layout: "turbo_rails/frame"
  end

  # Top-level list row open/close (Step 3): full `_show` / `_close` inside
  # `<turbo-frame id="…">` matching `params[:update]`.
  def render_row_turbo(mode)
    @inline_forms_turbo_row = true
    template = (mode == :close) ? "inline_forms/row_close" : "inline_forms/row_show"
    layout = turbo_frame_request? ? "turbo_rails/frame" : "inline_forms"
    render template, layout: layout
  end

  # HTML row open/close is allowed for normal models, and for +not_accessible_through_html?+
  # models (e.g. Photo) when the request targets a nested associated list row
  # (+params[:update]+ like +apartment_1_photo_5+), not bare top-level CRUD.
  def row_html_turbo_allowed?
    return true unless @Klass.not_accessible_through_html?
    nested_associated_list_row_update?(params[:update])
  end

  # +apartment_1_photo_5+ → +["apartment","1","photo","5"]+ (≥4 segments, trailing id).
  # Differs from field spans (+apartment_1_photo_5_name+ ends with letters) and
  # top-level rows (+apartment_1+ — too few segments).
  def nested_associated_list_row_update?(update)
    parts = update.to_s.split("_")
    parts.length >= 4 && parts.last.match?(/\A\d+\z/)
  end

  # Get the class from the controller name.
  # CountryController < InlineFormsController, so what class are we?
  # TODO think about this a bit more.
  def getKlass #:doc:
    @Klass = self.controller_name.classify.constantize
    InlineForms.validate_plain_text_configuration_for!(@Klass)
    @Klass
  end

  def referenced_object
    @Klass.find(object_id_params)
  end

  def object_id_params
    params.require(:id)
  end

  def deep_hashify(ary)
    return ary.to_s if ary.length == 1
    { ary.shift => deep_hashify(ary) }
  end

  def deep_merge(h1, h2)
    return h1.merge(h2) unless h2.first[1].is_a? Hash
    h1.merge(h2){|key, first, second| deep_merge(first, second)}
  end

  def unravel(deep_hash, level=-1)
    level += 1
    return "#{'  '*level}\"#{deep_hash.first[0]}\": \"#{deep_hash.first[1]}\"\n" unless deep_hash.first[1].is_a? Hash
    a = "#{'  '*level}\"#{deep_hash.first[0]}\":\n"
    deep_hash.first[1].each do |k,v|
      a << unravel( { k => v}, level)
    end
    a
  end

  def revert_params
    params.require(:id).permit(:update)
  end

end
