require "test_helper"

class EnrollmentsControllerTest < ActionDispatch::IntegrationTest
  test "GET /enroll/:token for a pending user generates a candidate and renders the QR" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    get enroll_path(token: token)

    assert_response :success
    assert_match %r{<svg}, response.body
    assert user.reload.totp_candidate_secret.present?
  end

  test "GET /enroll/:token with a tampered token redirects to sign-in" do
    get enroll_path(token: "bogus-token")

    assert_redirected_to sign_in_path
  end

  test "GET /enroll/:token for a suspended user redirects to root" do
    user = users(:suspended_member)
    token = user.generate_token_for(:enrollment)

    get enroll_path(token: token)

    assert_redirected_to root_path
  end

  test "POST /enroll/:token with a valid code activates the pending user and signs them in" do
    user = users(:pending_member)
    user.begin_enrollment!
    token = user.generate_token_for(:enrollment)
    code = ROTP::TOTP.new(user.totp_candidate_secret).now

    post enroll_confirm_path(token: token), params: { enrollment: { code: code } }

    assert_redirected_to root_path
    user.reload
    assert user.active?
    assert user.totp_secret.present?
    assert_nil user.totp_candidate_secret
  end

  test "POST /enroll/:token with a wrong code re-renders the QR" do
    user = users(:pending_member)
    user.begin_enrollment!
    token = user.generate_token_for(:enrollment)

    post enroll_confirm_path(token: token), params: { enrollment: { code: "000000" } }

    assert_response :unprocessable_entity
    assert_match %r{<svg}, response.body
    refute user.reload.active?
  end

  test "POST /enroll/:token rotates the candidate on recovery without touching totp_secret until success" do
    user = users(:active_member)
    enroll_if_needed(user)
    original_secret = user.totp_secret

    # Start a recovery session
    get enroll_path(token: user.generate_token_for(:enrollment))

    assert user.reload.totp_candidate_secret.present?
    assert_equal original_secret, user.totp_secret, "in-use secret must not change before completion"
  end

  test "POST /enroll/:token is rejected when the user is rate limited" do
    user = users(:pending_member)
    user.begin_enrollment!
    token = user.generate_token_for(:enrollment)

    LoginFailureTracker::USER_LIMIT.times { LoginFailureTracker.track_user(user.id) }

    post enroll_confirm_path(token: token), params: { enrollment: { code: "000000" } }

    assert_redirected_to enroll_path(token: token)
    assert_equal I18n.t("auth.enrollment.rate_limited"), flash[:alert]
  end
end
