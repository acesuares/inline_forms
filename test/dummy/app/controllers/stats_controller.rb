# frozen_string_literal: true

# Bespoke report page: uses the inline_forms admin layout but is not an
# InlineFormsController, so @Klass is never set (mirrors StProject Stats).
class StatsController < ApplicationController
  layout "inline_forms"

  def show
  end
end
