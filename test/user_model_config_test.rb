# -*- encoding : utf-8 -*-

require "minitest/autorun"
require "inline_forms_installer/user_model_config"

class UserModelConfigTest < Minitest::Test
  def test_default_user
    cfg = InlineFormsInstaller::UserModelConfig.from_name("User")
    assert cfg.default?
    assert_equal "users", cfg.table_name
    assert_equal "devise_for :users, :path_prefix => 'auth'", cfg.devise_route_line
    assert_equal "/auth/users/sign_in", cfg.sign_in_path_fragment
  end

  def test_member
    cfg = InlineFormsInstaller::UserModelConfig.from_name("Member")
    refute cfg.default?
    assert_equal "Member", cfg.class_name
    assert_equal "members", cfg.table_name
    assert_equal "member_id", cfg.foreign_key
    assert_equal "members_roles", cfg.join_table
    assert_equal "MembersController", cfg.controller_name
    assert_includes cfg.devise_route_line, 'class_name: "Member"'
    assert_includes cfg.devise_route_line, 'path: "members"'
    assert_equal "/auth/members/sign_in", cfg.sign_in_path_fragment
  end

  def test_adapts_example_tests
    cfg = InlineFormsInstaller::UserModelConfig.from_name("Member")
    src = "user = User.find_or_initialize_by(email: \"admin@example.com\")\n"
    assert_includes cfg.adapt_example_test_source(src), "Member.find_or_initialize_by"
    guest = "assert_match %r{/auth/users/sign_in}, @response.redirect_url\n"
    assert_includes cfg.adapt_example_test_source(guest), "/auth/members/sign_in"
  end

  def test_rejects_invalid_constant
    assert_raises(ArgumentError) { InlineFormsInstaller::UserModelConfig.from_name("not-a-class") }
  end

  def test_from_env_defaults_to_user
    env = { "user_model" => "" }
    assert InlineFormsInstaller::UserModelConfig.from_env(env).default?
  end
end
