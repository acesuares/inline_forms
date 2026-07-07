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

  # Recognize `name:decimal_field{p,s}` on the command line and hoist the
  # precision/scale into `attr_options`. Rails' own
  # `Rails::Generators::GeneratedAttribute.parse` only honors the `{…}`
  # suffix for a hardcoded list of built-in types (`:string`, `:integer`,
  # `:primary_key`, `:decimal`, ...); for our custom `:decimal_field` it
  # just glues the braces onto the type symbol (`:"decimal_field{10,2}"`)
  # and `column_type` falls through to `:unknown`. Strip the braces here,
  # delegate to the original parse with a clean `name:decimal_field`, and
  # then attach the parsed numbers to attr_options so the migration
  # emitter can render `t.decimal :name, precision: P, scale: S`.
  #
  # Bare `name:decimal_field` (no braces) parses unchanged — the
  # migration emitter applies precision: 10, scale: 2 as the default.
  class << self
    unless method_defined?(:parse_with_inline_forms_decimal) || private_method_defined?(:parse_with_inline_forms_decimal)
      alias_method :parse_without_inline_forms_decimal, :parse
    end

    def parse(column_definition)
      if column_definition.is_a?(String) &&
         (m = column_definition.match(/\A(\w+):decimal_field\{(\d+),(\d+)\}\z/))
        attr = parse_without_inline_forms_decimal("#{m[1]}:decimal_field")
        attr.attr_options[:precision] = m[2].to_i
        attr.attr_options[:scale]     = m[3].to_i
        attr
      else
        parse_without_inline_forms_decimal(column_definition)
      end
    end
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
        SPECIAL_GENERATOR_NAMES.include?(name))
  end

  def attribute?
    not ( SPECIAL_GENERATOR_NAMES.include?(name) ||
        relation?)
  end
end
