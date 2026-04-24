require "test_helper"

class SignUpFlowTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "GET /sign-up renders the account form" do
    get sign_up_path

    assert_response :success
    assert_select "p.eyebrow", I18n.t("auth.sign_up.eyebrow")
    assert_select "label", I18n.t("auth.fields.pseudonym")
  end

  test "POST /sign-up creates an account and sends verification email" do
    assert_difference("User.count", 1) do
      post sign_up_path, params: {
        user: {
          email: "new@example.com",
          password: "password123",
          password_confirmation: "password123",
          pseudonym: "new_builder"
        }
      }.merge(spam_check_params(:sign_up))
    end

    user = User.order(:id).last

    assert_redirected_to root_path
    assert user.pending_enrollment?
    assert_nil user.email_verified_at
    assert_equal 1, ActionMailer::Base.deliveries.count

    follow_redirect!
    assert_select ".flash", I18n.t("auth.sign_up.success")
    assert_select ".site-nav a[href='#{profile_path(user.pseudonym)}']", text: user.pseudonym
  end

  test "POST /sign-up creates an account when turnstile verification succeeds with production-shaped config" do
    with_env("TURNSTILE_SECRET_KEY" => "secret", "TURNSTILE_SITE_KEY" => "site-key") do
      assert_difference("User.count", 1) do
        with_stubbed_turnstile_verification(true) do
          post sign_up_path, params: {
            user: {
              email: "turnstile@example.com",
              password: "password123",
              password_confirmation: "password123",
              pseudonym: "turnstile_builder"
            },
            "cf-turnstile-response" => "token"
          }.merge(spam_check_params(:sign_up))
        end
      end
    end

    user = User.order(:id).last

    assert_redirected_to root_path
    assert user.pending_enrollment?
  end

  test "POST /sign-up re-renders when the form is invalid" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "invalid",
          password: "password123",
          password_confirmation: "different",
          pseudonym: "bad name"
        }
      }.merge(spam_check_params(:sign_up))
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", 1
  end

  test "POST /sign-up blocks creation when turnstile verification fails" do
    with_env("TURNSTILE_SECRET_KEY" => "secret") do
      assert_no_difference("User.count") do
        post sign_up_path, params: {
          user: {
            email: "blocked@example.com",
            password: "password123",
            password_confirmation: "password123",
            pseudonym: "blocked_builder"
          }
        }.merge(spam_check_params(:sign_up))
      end
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /#{Regexp.escape(I18n.t("activerecord.errors.models.user.attributes.base.turnstile_failed"))}/
  end

  test "POST /sign-up blocks disposable email domains" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "throwaway@mailinator.com",
          password: "password123",
          password_confirmation: "password123",
          pseudonym: "temporary_builder"
        }
      }.merge(spam_check_params(:sign_up))
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /#{Regexp.escape(I18n.t("activerecord.errors.models.user.attributes.email.disposable"))}/
  end

  test "POST /sign-up blocks honeypot submissions" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "honeypot@example.com",
          password: "password123",
          password_confirmation: "password123",
          pseudonym: "honeypot_builder"
        }
      }.merge(spam_check_params(:sign_up, honeypot: "https://spam.example"))
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /#{Regexp.escape(I18n.t("activerecord.errors.models.user.attributes.base.honeypot_triggered"))}/
  end

  test "POST /sign-up blocks forms submitted too quickly" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email: "fast@example.com",
          password: "password123",
          password_confirmation: "password123",
          pseudonym: "fast_builder"
        }
      }.merge(spam_check_params(:sign_up, started_at: 1.second.ago))
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /#{Regexp.escape(I18n.t("activerecord.errors.models.user.attributes.base.submitted_too_quickly"))}/
  end
end
