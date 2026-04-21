require "test_helper"

class EmailVerificationFlowTest < ActionDispatch::IntegrationTest
  test "verification link activates the account" do
    user = users(:pending_member)

    get email_verification_path(token: user.generate_token_for(:email_verification))

    assert_redirected_to sign_in_path
    follow_redirect!

    assert_select ".flash", I18n.t("auth.email_verification.success")
    assert user.reload.active?
    assert user.email_verified?
  end

  test "already verified account sees the already verified notice" do
    user = users(:active_member)

    get email_verification_path(token: user.generate_token_for(:email_verification))

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.email_verification.already_verified")
  end

  test "invalid verification token redirects to sign in" do
    get email_verification_path(token: "invalid")

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.email_verification.invalid")
  end

  test "suspended account verification link is blocked" do
    user = users(:suspended_member)

    get email_verification_path(token: user.generate_token_for(:email_verification))

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.account_states.suspended")
  end

  test "banned account verification link is blocked" do
    user = users(:banned_member)

    get email_verification_path(token: user.generate_token_for(:email_verification))

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.account_states.banned")
  end
end
