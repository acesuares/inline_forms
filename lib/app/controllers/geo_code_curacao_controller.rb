  # Used in autocomplete
  #
  class GeoCodeCuracaoController < ApplicationController
    def index
      @term = params[:term]
      @streets = GeoCodeCuracao.lookup('%' + @term + '%')
      respond_to do |format|
        format.html { render :geo_code_curacao }
        format.js { render :geo_code_curacao }
      end
    end

  end
