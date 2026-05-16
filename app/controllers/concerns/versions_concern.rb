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
        format.html { render "inline_forms/versions_panel", layout: "turbo_rails/frame" }
      end
    else
      respond_to do |format|
        format.html { render "inline_forms/versions_list_panel", layout: "turbo_rails/frame" }
      end
    end
  end
end
