require "test_helper"

class SignUpFlowTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "GET /sign-up renders the account form" do
    get sign_up_path

    assert_response :success
    assert_select "h1", I18n.t("auth.sign_up.title")
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
      }
    end

    user = User.order(:id).last

    assert_redirected_to root_path
    assert user.pending_email_verification?
    assert_nil user.email_verified_at
    assert_equal 1, ActionMailer::Base.deliveries.count

    follow_redirect!
    assert_select ".flash", I18n.t("auth.sign_up.success")
    assert_select ".site-nav__status a[href='#{profile_path(user.pseudonym)}']", text: user.pseudonym
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
      }
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
        }
      end
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /#{Regexp.escape(I18n.t("activerecord.errors.models.user.attributes.base.turnstile_failed"))}/
  end
end
