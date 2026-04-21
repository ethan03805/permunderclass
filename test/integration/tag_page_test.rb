require "test_helper"

class TagPageTest < ActionDispatch::IntegrationTest
  test "GET /tags/:slug shows tag feed" do
    get tag_path(tags(:active_tag).slug)
    assert_response :success
    assert_select "h1.section-title", I18n.t("tags.title", name: tags(:active_tag).name)
    assert_select ".post-card", count: 1
    assert_select ".post-card", text: /#{posts(:removed_post).title}/, count: 0
  end

  test "archived tag returns redirect" do
    get tag_path(tags(:archived_tag).slug)
    assert_redirected_to root_path
  end

  test "unknown tag returns redirect" do
    get tag_path("nonexistent")
    assert_redirected_to root_path
  end

  test "tag feed respects sort params" do
    get tag_path(tags(:active_tag).slug), params: { sort: "new" }
    assert_response :success
    assert_select ".filter-link.is-active", text: I18n.t("feed.sorts.new")
  end
end
