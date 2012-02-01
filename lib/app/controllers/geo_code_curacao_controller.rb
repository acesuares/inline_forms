  # Used in autocomplete
  #
  class GeoCodeCuracaoController < ApplicationController
    def list_streets
      @term = params[:term]
      @streets = GeoCodeCuracao.lookup('%' + @term + '%')
    end

  end
