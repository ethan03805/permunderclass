require "test_helper"

class HomePageTest < ActionDispatch::IntegrationTest
  test "GET / renders the shared application shell and feed" do
    get root_path

    assert_response :success
    assert_no_match(/translation missing/i, @response.body)

    assert_select "html[lang=?]", I18n.locale.to_s
    assert_select "title", "#{I18n.t('feed.title')} · #{I18n.t('app.title')}"
    assert_select "a.skip-link[href=?]", "#main-content", text: I18n.t("layouts.skip_to_content")
    assert_select "header.site-header", 1
    assert_select "nav.site-nav[aria-label=?]", I18n.t("nav.primary")
    assert_select "main#main-content", 1
    assert_select "footer.site-footer", 1
    assert_select "a.site-title", I18n.t("app.name")
    assert_select ".feed-layout", 1
  end
end
