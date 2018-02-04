module VersionsConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_paper_trail_whodunnit
  end

  def list_versions
    @update_span = params[:update]
    @object = referenced_object
    respond_to do |format|
      format.html { } unless @Klass.not_accessible_through_html?
      format.js { render :versions_list }
    end
  end

  def close_versions_list
    @update_span = params[:update]
    @object = referenced_object
    respond_to do |format|
      format.html { } unless @Klass.not_accessible_through_html?
      format.js { render :versions }
    end
  end
end
