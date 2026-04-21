require "test_helper"

class FeedTest < ActionDispatch::IntegrationTest
  test "GET / renders feed with published posts" do
    get root_path
    assert_response :success
    assert_select ".post-card", count: Post.feed_published.count
  end

  test "feed supports hot sort by default" do
    get root_path
    assert_response :success
    assert_select ".filter-link.is-active", text: I18n.t("feed.sorts.hot")
  end

  test "feed supports new sort" do
    get root_path, params: { sort: "new" }
    assert_response :success
    assert_select ".filter-link.is-active", text: I18n.t("feed.sorts.new")
  end

  test "feed supports top sort with window" do
    get root_path, params: { sort: "top", window: "week" }
    assert_response :success
    assert_select ".filter-link.is-active", text: I18n.t("feed.sorts.top")
    assert_select "select[name=?] option[selected][value=?]", "window", "week", text: I18n.t("feed.windows.week")
  end

  test "feed filters by type" do
    get root_path, params: { types: [ "discussion" ] }
    assert_response :success
    assert_select ".post-card", count: Post.feed_published.where(post_type: :discussion).count
  end

  test "feed filters by tag" do
    get root_path, params: { tag: tags(:active_tag).slug }
    assert_response :success
    assert_select ".post-card", count: 1
  end

  test "feed paginates" do
    30.times do |i|
      Post.create!(user: users(:active_member), post_type: :discussion, title: "Paginated #{i}", body: "Body")
    end

    get root_path, params: { page: 1 }
    assert_response :success
    assert_select ".pagination", 1
  end

  test "pagination preserves feed state" do
    30.times do |i|
      post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Tagged #{i}", body: "Body")
      PostTag.create!(post: post, tag: tags(:active_tag))
    end

    get root_path, params: { sort: "top", window: "week", types: [ "discussion" ], tag: tags(:active_tag).slug }

    assert_response :success
    assert_select ".pagination__link[href*='sort=top'][href*='window=week'][href*='types%5B%5D=discussion'][href*='tag=#{tags(:active_tag).slug}']"
  end

  test "rewrite requested posts do not appear in feed" do
    get root_path
    assert_response :success
    assert_select ".post-card", text: /#{posts(:rewrite_requested_post).title}/, count: 0
  end

  test "removed posts do not appear in feed" do
    get root_path
    assert_response :success
    assert_select ".post-card", text: /#{posts(:removed_post).title}/, count: 0
  end

  test "archived tags are ignored in direct feed tag filtering" do
    get root_path, params: { tag: tags(:archived_tag).slug }

    assert_response :success
    assert_select ".post-card", count: 0
  end
end
