  # Used in autocomplete
  #
  class GeoCodeCuracaoController < ApplicationController
    def index
      @term = params[:term]
      respond_to do |format|
        format.html { render 'inline_forms/_list', :layout => 'inline_forms' } unless @Klass.not_accessible_through_html?
        format.js { render :list }
      end
    end

  end
