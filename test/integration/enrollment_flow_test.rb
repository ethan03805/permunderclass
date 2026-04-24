require "test_helper"

class EnrollmentFlowTest < ActionDispatch::IntegrationTest
  test "full happy path: sign-up -> email -> enroll -> signed in" do
    perform_enqueued_jobs do
      with_stubbed_turnstile_verification(true) do
        post sign_up_path, params: {
          user: { pseudonym: "newbie", email: "newbie@example.com" },
          **spam_check_params(:sign_up)
        }
      end
    end

    user = User.find_by!(email: "newbie@example.com")
    mail = ActionMailer::Base.deliveries.last
    token = mail.body.encoded[%r{/enroll/([A-Za-z0-9_\-=]+)}, 1]
    assert token.present?

    # GET the enrollment page
    get enroll_path(token: token)
    assert_response :success
    assert user.reload.totp_candidate_secret.present?

    # Submit a valid code
    code = ROTP::TOTP.new(user.totp_candidate_secret).now
    post enroll_confirm_path(token: token), params: { enrollment: { code: code } }

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
    user.reload
    assert user.active?
    assert user.totp_secret.present?
    assert_nil user.totp_candidate_secret
  end

  test "refreshing the enrollment page keeps the same candidate" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    get enroll_path(token: token)
    first_secret = user.reload.totp_candidate_secret

    get enroll_path(token: token)
    second_secret = user.reload.totp_candidate_secret

    assert_equal first_secret, second_secret
  end

  test "expired token redirects to sign-in" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    travel 31.minutes do
      get enroll_path(token: token)
    end

    assert_redirected_to sign_in_path
  end
end
