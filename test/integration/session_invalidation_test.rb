require "test_helper"

class SessionInvalidationTest < ActionDispatch::IntegrationTest
  test "a signed-in session is invalidated when sessions_generation bumps" do
    user = users(:active_member)
    enroll_if_needed(user)
    sign_in_as(user)

    get root_path
    assert_response :success
    assert_select "nav.site-nav" do
      assert_select "a", text: user.pseudonym
      assert_select "button", text: I18n.t("nav.sign_out")
    end

    # Simulate recovery completion on another device:
    user.update!(sessions_generation: user.sessions_generation + 1)

    get root_path
    assert_response :success
    assert_select "nav.site-nav" do
      assert_select "a", text: user.pseudonym, count: 0
      assert_select "button", text: I18n.t("nav.sign_out"), count: 0
      assert_select "a", text: I18n.t("nav.sign_in")
    end
  end
end
