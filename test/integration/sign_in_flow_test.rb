require "test_helper"

class SignInFlowTest < ActionDispatch::IntegrationTest
  test "sign-in form bypasses turbo preview caching" do
    get sign_in_path

    assert_select "form[action='#{sign_in_path}'][data-turbo='false']"
  end

  test "active user signs in with email + valid TOTP code" do
    user = users(:active_member)
    enroll_if_needed(user)

    post sign_in_path, params: {
      session: { email: user.email, code: valid_totp_code_for(user) }
    }

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
    follow_redirect!
    assert_select "a[href='#{profile_path(user.pseudonym)}']", text: user.pseudonym
    assert_select "form[action='#{sign_out_path}'][data-turbo='false']"
  end

  test "wrong code shows generic error and does not sign in" do
    user = users(:active_member)
    enroll_if_needed(user)

    post sign_in_path, params: {
      session: { email: user.email, code: "000000" }
    }

    assert_redirected_to sign_in_path
    assert_nil session[:user_id]
  end

  test "unknown email shows the same generic error" do
    post sign_in_path, params: {
      session: { email: "nobody@example.com", code: "123456" }
    }

    assert_redirected_to sign_in_path
    assert_equal I18n.t("auth.sign_in.invalid_credentials"), flash[:alert]
  end

  test "pending_enrollment user cannot sign in" do
    user = users(:pending_member)
    # note: pending user has no totp_secret, so no code will validate

    post sign_in_path, params: {
      session: { email: user.email, code: "123456" }
    }

    assert_redirected_to sign_in_path
    assert_nil session[:user_id]
  end

  test "suspended user is shown a blocked message" do
    user = users(:suspended_member)

    post sign_in_path, params: {
      session: { email: user.email, code: "123456" }
    }

    assert_redirected_to sign_in_path
    assert_match I18n.t("auth.guards.account_states.suspended"), flash[:alert]
  end

  test "replayed TOTP code is rejected on second use" do
    user = users(:active_member)
    enroll_if_needed(user)
    code = valid_totp_code_for(user)

    post sign_in_path, params: { session: { email: user.email, code: code } }
    assert_redirected_to root_path

    delete sign_out_path
    assert_nil session[:user_id]

    post sign_in_path, params: { session: { email: user.email, code: code } }
    assert_redirected_to sign_in_path, "replayed code must not sign in"
  end
end
