require "test_helper"

class RecoveryFlowTest < ActionDispatch::IntegrationTest
  test "lost phone: request recovery, click link, re-enroll, signed in with new secret" do
    user = users(:active_member)
    enroll_if_needed(user)
    original_secret = user.totp_secret

    perform_enqueued_jobs do
      with_stubbed_turnstile_verification(true) do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    mail = ActionMailer::Base.deliveries.last
    token = mail.body.encoded[%r{/enroll/([A-Za-z0-9_\-=]+)}, 1]

    # Visiting the link must NOT mutate totp_secret
    get enroll_path(token: token)
    user.reload
    assert_equal original_secret, user.totp_secret, "old authenticator must still work during recovery"
    assert user.totp_candidate_secret.present?

    # Submit a valid code against the new candidate
    new_code = ROTP::TOTP.new(user.totp_candidate_secret).now
    post enroll_confirm_path(token: token), params: { enrollment: { code: new_code } }

    assert_redirected_to root_path
    user.reload
    refute_equal original_secret, user.totp_secret
    assert_nil user.totp_candidate_secret
  end

  test "recovery bumps sessions_generation so other-device sessions are signed out" do
    user = users(:active_member)
    enroll_if_needed(user)

    perform_enqueued_jobs do
      with_stubbed_turnstile_verification(true) do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    token = ActionMailer::Base.deliveries.last.body.encoded[%r{/enroll/([A-Za-z0-9_\-=]+)}, 1]
    get enroll_path(token: token)
    code = ROTP::TOTP.new(user.reload.totp_candidate_secret).now

    before = user.sessions_generation
    post enroll_confirm_path(token: token), params: { enrollment: { code: code } }

    assert_equal before + 1, user.reload.sessions_generation
  end

  test "recovery works for pending_enrollment users as a resend of the enrollment email" do
    user = users(:pending_member)

    with_stubbed_turnstile_verification(true) do
      assert_enqueued_emails 1 do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end
  end
end
