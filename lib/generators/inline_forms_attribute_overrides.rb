# -*- encoding : utf-8 -*-
require "rails/generators"
require "rails/generators/generated_attribute"
require "inline_forms"

# Shared `Rails::Generators::GeneratedAttribute` extensions used by both
# `InlineForms::InlineFormsGenerator` (`rails g inline_forms`) and
# `InlineForms::InlineFormsAddtoGenerator` (`rails g inline_forms_addto`).
#
# Loaded once; idempotent (the `class_eval` re-defines methods to the
# same bodies on a re-require, no behavior drift).
Rails::Generators::GeneratedAttribute.class_eval do
  # Override Rails::Generators::GeneratedAttribute.valid_type? so that our
  # custom field types (dropdown, check_list, image_field, rich_text, ...)
  # pass through parsing. We do our own unknown-type detection later (with
  # Thor::Error + --allow-unknown), so it is safe to accept everything here.
  #
  # Rails 6.1 used to rescue ActiveRecord::Base.connection failures, which
  # masked the issue; Rails 7+ raises NameError when ActiveRecord is not
  # loaded yet, breaking generator unit tests.
  def self.valid_type?(_type)
    true
  end

  # Deducts the column_type for migrations from the type.
  #
  # We first merge the Special Column Types with the Default Column Types,
  # which has the effect that the Default Column Types with the same key
  # override the Special Column Types.
  #
  # If the type is not in the merged hash, then column_type defaults to :unknown
  #
  # You are advised to check your migrations for the :unknown, because either you made a
  # typo in the generator command line or you need to add a Form Element!
  def column_type
    InlineForms::SPECIAL_COLUMN_TYPES
      .merge(InlineForms::DEFAULT_COLUMN_TYPES)
      .merge(InlineForms::RELATIONS)
      .merge(InlineForms::SPECIAL_RELATIONS)[type] || :unknown
  end

  # Override the attribute_type to include our special column types.
  #
  # If a type is not in the Special Column Type hash, then the default
  # column type hash is used, and if that fails, the attribute_type
  # will be :unknown. Make sure to check your models for the :unknown.
  def attribute_type
    if InlineForms::SPECIAL_COLUMN_TYPES.merge(InlineForms::RELATIONS).has_key?(type)
      type
    else
      InlineForms::DEFAULT_FORM_ELEMENTS[type] || :unknown
    end
  end

  def special_relation?
    InlineForms::SPECIAL_RELATIONS.has_key?(type)
  end

  def relation?
    InlineForms::RELATIONS.has_key?(type) || special_relation?
  end

  # Special "attribute" names that drive the generator (presentation,
  # ordering, search, etc.) but never become real columns or fields.
  SPECIAL_GENERATOR_NAMES = %w[
    _presentation
    _order
    _list_order
    _list_search
    _enabled
    _id
    _no_migration
    _no_model
  ].freeze unless const_defined?(:SPECIAL_GENERATOR_NAMES)

  def migration?
    not ( column_type == :no_migration  ||
        SPECIAL_GENERATOR_NAMES.include?(name) )
  end

  def attribute?
    not ( SPECIAL_GENERATOR_NAMES.include?(name) ||
        relation? )
  end
end
