require "test_helper"

class SignUpFlowTest < ActionDispatch::IntegrationTest
  test "sign-up creates a pending_enrollment user, enqueues enrollment email, and does not start a session" do
    with_stubbed_turnstile_verification(true) do
      assert_enqueued_emails 1 do
        assert_difference -> { User.count }, 1 do
          post sign_up_path, params: {
            user: { pseudonym: "newbie", email: "newbie@example.com" },
            **spam_check_params(:sign_up)
          }
        end
      end
    end

    user = User.order(:created_at).last
    assert user.pending_enrollment?
    assert_nil user.totp_secret
    assert_redirected_to sign_in_path
    assert_nil session[:user_id], "sign-up must not create a session"
  end

  test "sign-up with a disposable email is rejected" do
    with_stubbed_turnstile_verification(true) do
      assert_no_difference -> { User.count } do
        post sign_up_path, params: {
          user: { pseudonym: "spammer", email: "spammer@mailinator.com" },
          **spam_check_params(:sign_up)
        }
      end
    end

    assert_response :unprocessable_entity
  end

  test "sign-up with failed Turnstile is rejected" do
    with_stubbed_turnstile_verification(false) do
      assert_no_difference -> { User.count } do
        post sign_up_path, params: {
          user: { pseudonym: "newbie", email: "newbie@example.com" },
          **spam_check_params(:sign_up)
        }
      end
    end

    assert_response :unprocessable_entity
  end
end
