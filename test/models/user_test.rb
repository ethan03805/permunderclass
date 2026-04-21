require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "fixture user is valid" do
    assert users(:active_member).valid?
  end

  test "pseudonym format is restricted" do
    user = User.new(
      email: "format@example.com",
      password: "password123",
      password_confirmation: "password123",
      pseudonym: "bad pseudonym"
    )

    assert_not user.valid?
    assert_includes user.errors[:pseudonym], I18n.t("activerecord.errors.models.user.attributes.pseudonym.invalid")
  end

  test "email uniqueness is case insensitive" do
    user = User.new(
      email: "ACTIVE@example.com",
      password: "password123",
      password_confirmation: "password123",
      pseudonym: "another_builder"
    )

    assert_not user.valid?
    assert_includes user.errors[:email], I18n.t("activerecord.errors.models.user.attributes.email.taken")
  end

  test "pseudonym uniqueness is case insensitive" do
    user = User.new(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      pseudonym: "ACTIVE_BUILDER"
    )

    assert_not user.valid?
    assert_includes user.errors[:pseudonym], I18n.t("activerecord.errors.models.user.attributes.pseudonym.taken")
  end

  test "verify_email activates pending account" do
    user = users(:pending_member)

    user.verify_email!

    assert user.email_verified?
    assert user.active?
  end

  test "password must be at least eight characters when present" do
    user = User.new(
      email: "short@example.com",
      password: "short",
      password_confirmation: "short",
      pseudonym: "shortpass"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], I18n.t("activerecord.errors.models.user.attributes.password.too_short", count: 8)
  end

  test "verify_email does not reactivate suspended users" do
    user = users(:suspended_member)

    user.verify_email!

    assert user.suspended?
  end
end
