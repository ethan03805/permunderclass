require "test_helper"

class SessionFlowTest < ActionDispatch::IntegrationTest
  test "active user can sign in and sign out" do
    sign_in_as(users(:active_member))

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.sign_in.success")
    assert_select "form.button_to button", I18n.t("nav.sign_out")

    delete sign_out_path

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.sign_out.success")
  end

  test "pending user can sign in but sees verification notice" do
    sign_in_as(users(:pending_member))

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.sign_in.pending_email_verification")
    assert_select ".site-nav__status span", text: I18n.t("nav.account_states.pending_email_verification")
  end

  test "suspended user is blocked from signing in" do
    sign_in_as(users(:suspended_member))

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.account_states.suspended")
  end

  test "banned user is blocked from signing in" do
    sign_in_as(users(:banned_member))

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.account_states.banned")
  end
end
