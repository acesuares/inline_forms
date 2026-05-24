# -*- encoding : utf-8 -*-
require "active_support/core_ext/string/inflections"

module InlineFormsInstaller
  # Devise mapping stays on :users (Warden scope :user → current_user in inline_forms).
  # A custom class (e.g. Member) uses members table, /members routes, and
  # devise_for :users, class_name: "Member", path: "members".
  class UserModelConfig
    DEFAULT_CLASS = "User"

    def self.from_env(env = ENV)
      from_name(env["user_model"].to_s.strip)
    end

    def self.from_name(name)
      name = DEFAULT_CLASS if name.empty?
      new(name)
    end

    def initialize(class_name)
      unless class_name.match?(/\A[A-Z][A-Za-z0-9]*\z/)
        raise ArgumentError, "user model must be a Ruby constant (e.g. User, Member)"
      end

      @class_name = class_name
    end

    attr_reader :class_name

    def default?
      class_name == DEFAULT_CLASS
    end

    def table_name
      class_name.tableize
    end

    def plural_route
      table_name
    end

    def foreign_key
      "#{class_name.underscore}_id"
    end

    # Rails HABTM join table: plural model names in lexical order (roles_users, members_roles).
    def join_table
      return "roles_users" if default?

      [table_name, "roles"].sort.join("_")
    end

    def controller_name
      "#{class_name.pluralize}Controller"
    end

    def controller_path
      "app/controllers/#{table_name}_controller.rb"
    end

    def model_path
      "app/models/#{class_name.underscore}.rb"
    end

    def tab_key
      class_name.underscore.to_sym
    end

    def devise_migration_basename
      "devise_create_#{table_name}"
    end

    def devise_migration_class
      "DeviseCreate#{class_name.pluralize}"
    end

    def join_migration_basename
      "inline_forms_create_join_table_#{class_name.underscore}_role"
    end

    def join_migration_class
      "InlineFormsCreateJoinTable#{class_name}Role"
    end

    def devise_route_line
      if default?
        "devise_for :users, :path_prefix => 'auth'"
      else
        "devise_for :users, class_name: \"#{class_name}\", path: \"#{plural_route}\", path_prefix: 'auth'"
      end
    end

    def sign_in_path_fragment
      "/auth/#{default? ? 'users' : plural_route}/sign_in"
    end

    def adapt_example_test_source(content)
      return content if default?

      content = content.gsub("User", class_name)
      content.gsub(%r{/auth/users/sign_in}, sign_in_path_fragment)
    end
  end
end
