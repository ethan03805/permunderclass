require "test_helper"

class RecoveriesControllerTest < ActionDispatch::IntegrationTest
  test "POST /recover with a known active email enqueues an enrollment_link email" do
    user = users(:active_member)

    with_stubbed_turnstile_verification(true) do
      assert_enqueued_emails 1 do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t("auth.recovery.submitted"), flash[:notice]
  end

  test "POST /recover with an unknown email does not enqueue email but shows same notice" do
    with_stubbed_turnstile_verification(true) do
      assert_no_enqueued_emails do
        post recover_path, params: { recovery: { email: "nobody@example.com" } }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t("auth.recovery.submitted"), flash[:notice]
  end

  test "POST /recover with a suspended user does not enqueue email but shows same notice" do
    user = users(:suspended_member)

    with_stubbed_turnstile_verification(true) do
      assert_no_enqueued_emails do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    assert_redirected_to sign_in_path
  end

  test "POST /recover bumps enrollment_token_generation to invalidate prior links" do
    user = users(:active_member)
    before = user.enrollment_token_generation

    with_stubbed_turnstile_verification(true) do
      post recover_path, params: { recovery: { email: user.email } }
    end

    assert_equal before + 1, user.reload.enrollment_token_generation
  end

  test "POST /recover with failed Turnstile does not enqueue email" do
    user = users(:active_member)

    with_stubbed_turnstile_verification(false) do
      assert_no_enqueued_emails do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    assert_redirected_to sign_in_path
  end
end
