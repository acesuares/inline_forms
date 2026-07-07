class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # PaperTrail 16 defaults to `on: [:create, :update, :destroy, :touch]`.
  # ActionText's `belongs_to :record, polymorphic: true, touch: true` (set by
  # `has_rich_text`) calls `parent.touch` on every rich-text save, which
  # produced a parent-side `update` version with an empty changeset — visible
  # in the inline_forms versions panel as a meaningless "empty" row whose
  # Restore link reifies the same state (no-op). Excluding `:touch` here
  # suppresses that noise without affecting real attribute updates.
  has_paper_trail on: [ :create, :update, :destroy ]

  attr_writer :inline_forms_attribute_list

  # will_paginate reads Klass.per_page (class level), not instance ivars.
  self.per_page = 7

  # Default list ordering for inline_forms #index/#create and nested
  # associated lists. Subclasses override via
  #   scope :inline_forms_list, -> { order(:col, :id) }
  # (typically emitted by `rails g inline_forms <Model> _list_order:<col>`).
  # `all` is a no-op so the gem adds no ORDER BY by default; pair with
  # explicit named scopes rather than `default_scope` so callers can
  # `unscope`/`reorder` cleanly.
  scope :inline_forms_list, -> { all }

  # Default list search; no-op so the gem's search box is inert until a model
  # opts in via
  #   scope :inline_forms_search, ->(q) { where("col LIKE ?", "%#{q}%") }
  # (emitted by `_list_search:<col>` in the generator).
  scope :inline_forms_search, ->(_q) { all }

  # Wrapper for @model.human_attribute_name -> Model.human_attribute_name
  def human_attribute_name(*args)
    self.class.human_attribute_name(*args)
  end

  def self.not_accessible_through_html?
    false
  end
end
