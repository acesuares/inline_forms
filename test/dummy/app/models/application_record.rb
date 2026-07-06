# frozen_string_literal: true

# Mirrors the host-app contract the installer's application_record.rb template
# establishes (lib/generators/templates/application_record.rb): paper_trail on
# every model, will_paginate per_page, inline_forms list/search scopes, and
# the not_accessible_through_html? default the engine controller consults.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  has_paper_trail on: [:create, :update, :destroy]

  attr_writer :inline_forms_attribute_list

  self.per_page = 7

  scope :inline_forms_list, -> { all }
  scope :inline_forms_search, ->(_q) { all }

  def human_attribute_name(*args)
    self.class.human_attribute_name(*args)
  end

  def self.not_accessible_through_html?
    false
  end
end
