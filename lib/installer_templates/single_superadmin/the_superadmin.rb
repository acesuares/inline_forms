# frozen_string_literal: true

# THE superadmin: user 1 holding the role "superadmin" (SingleSuperadmin).
# Nobody else can be made superadmin, so tests sign in as this user. Made the
# first time it is asked for, found after; safe to call more than once in a
# test. Attributes given are updated on it, inside the test's transaction.
module TheSuperadmin
  EMAIL = "admin@example.com"
  PASSWORD = "admin999"

  def self.user(**attributes)
    role = Role.find_or_create_by!(name: SingleSuperadmin::SUPERADMIN_ROLE) { |r| r.description = "Super Admin can access all." }
    user = User.find_by(id: SingleSuperadmin::SUPERADMIN_ID) || create_user_one
    user.update!(attributes) if attributes.any?
    user.roles << role unless user.roles.include?(role)
    user
  end

  def self.create_user_one
    locale = Locale.find_or_create_by!(name: "en") { |l| l.title = "English" }
    User.create!(id: SingleSuperadmin::SUPERADMIN_ID, name: "Admin", email: EMAIL, locale: locale,
                 password: PASSWORD, password_confirmation: PASSWORD)
  end

  def the_superadmin(**attributes)
    TheSuperadmin.user(**attributes)
  end
end
