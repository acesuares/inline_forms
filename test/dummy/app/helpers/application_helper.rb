# frozen_string_literal: true

# Mirrors the helper the installer writes into host apps (installer_core.rb);
# the full `layouts/inline_forms` chrome needs it.
module ApplicationHelper
  def application_name
    "Dummy"
  end

  def application_title
    "Dummy"
  end
end
