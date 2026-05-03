# frozen_string_literal: true

require_relative "test_helper"
require "logger"
require "active_model"
require "action_dispatch"

# Record double with the same +model_name+ routing key as +resources :articles+
# (a class nested under Minitest::Test would get +inline_edit_…_article+, not +article+).
class InlineFormsArticlesRouteDouble
  include ActiveModel::Model
  include ActiveModel::Conversion

  attr_accessor :id

  def self.model_name
    ActiveModel::Name.new(self, nil, "Article")
  end

  def initialize(id = 1)
    @id = id
  end

  def persisted?
    true
  end

  def to_param
    id.to_s
  end
end

# Class-only double for +polymorphic_path(Model)+ (collection +articles+).
class InlineFormsArticleClassRouteDouble
  def self.model_name
    ActiveModel::Name.new(self, nil, "Article")
  end
end

# Parity between polymorphic URL helpers and named +edit_article_path+,
# +article_path+, and +articles_path+ for a standard +resources :articles+
# route (no full Rails app boot).
class InlineEditPolymorphicPathTest < Minitest::Test
  def setup
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { resources :articles }
    routes = @routes
    holder_class = Class.new do
      include routes.url_helpers
    end
    holder_class.default_url_options = { only_path: true }
    @holder = holder_class.new
  end

  def test_edit_polymorphic_path_matches_named_edit_helper
    article = InlineFormsArticlesRouteDouble.new(42)
    options = {
      attribute: "title",
      form_element: "text_field",
      update: "field_article_42_title"
    }
    poly = @holder.edit_polymorphic_path(article, **options)
    named = @holder.edit_article_path(article, **options)
    assert_equal named, poly
  end

  def test_member_polymorphic_path_matches_article_path
    article = InlineFormsArticlesRouteDouble.new(7)
    options = { update: "span", close: true }
    poly = @holder.polymorphic_path(article, **options)
    named = @holder.article_path(article, **options)
    assert_equal named, poly
  end

  def test_collection_polymorphic_path_matches_articles_path
    options = { update: "list", parent_class: "Parent", parent_id: "3" }
    poly = @holder.polymorphic_path(InlineFormsArticleClassRouteDouble, **options)
    named = @holder.articles_path(**options)
    assert_equal named, poly
  end
end
