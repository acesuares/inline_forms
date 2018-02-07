module VersionsConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_paper_trail_whodunnit
  end

  def list_versions
    @update_span = params[:update]
    @object = referenced_object
    close = params[:close] || false
    if close
      respond_to do |format|
        format.js { render :versions }
      end
    else
      respond_to do |format|
        format.html { } unless @Klass.not_accessible_through_html?
        format.js { render :versions_list }
      end
    end
  end
end
