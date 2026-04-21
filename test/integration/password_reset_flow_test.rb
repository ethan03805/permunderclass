require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "requesting a password reset sends instructions when the account exists" do
    post password_reset_path, params: {
      password_reset: {
        email: users(:active_member).email
      }
    }

    assert_redirected_to sign_in_path
    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test "requesting a password reset always shows the same response" do
    post password_reset_path, params: {
      password_reset: {
        email: "missing@example.com"
      }
    }

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.password_reset.create.success")
  end

  test "updating the password with a valid token succeeds" do
    user = users(:active_member)

    patch password_reset_token_path(token: user.generate_token_for(:password_reset)), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to root_path
    assert user.reload.authenticate("newpassword123")
  end

  test "invalid password reset token is rejected" do
    patch password_reset_token_path(token: "invalid"), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to password_reset_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.password_reset.invalid")
  end

  test "blank password reset submission is rejected" do
    user = users(:active_member)

    patch password_reset_token_path(token: user.generate_token_for(:password_reset)), params: {
      user: {
        password: "",
        password_confirmation: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary", 1
  end

  test "suspended account cannot reset its password with a valid token" do
    user = users(:suspended_member)

    get password_reset_token_path(token: user.generate_token_for(:password_reset))

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.account_states.suspended")
  end

  test "banned account cannot reset its password with a valid token" do
    user = users(:banned_member)

    get password_reset_token_path(token: user.generate_token_for(:password_reset))

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.account_states.banned")
  end
end
