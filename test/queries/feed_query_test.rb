require "test_helper"

class FeedQueryTest < ActiveSupport::TestCase
  test "default sort is hot" do
    query = FeedQuery.new({})
    assert_equal "hot", query.sort
  end

  test "default window is all" do
    query = FeedQuery.new({})
    assert_equal "all", query.window
  end

  test "default page is 1" do
    query = FeedQuery.new(page: "0")
    assert_equal 1, query.page
  end

  test "invalid sort falls back to hot" do
    query = FeedQuery.new(sort: "invalid")
    assert_equal "hot", query.sort
  end

  test "invalid window falls back to all" do
    query = FeedQuery.new(window: "invalid")
    assert_equal "all", query.window
  end

  test "types filters to valid post types only" do
    query = FeedQuery.new(types: [ "shipped", "invalid" ])
    assert_equal [ "shipped" ], query.types
  end

  test "call returns only published posts" do
    result = FeedQuery.new({}).call
    post_ids = result[:posts].map(&:id)
    assert_includes post_ids, posts(:commented_post).id
    assert_not_includes post_ids, posts(:rewrite_requested_post).id
    assert_not_includes post_ids, posts(:removed_post).id
  end

  test "call paginates results" do
    30.times do |i|
      Post.create!(user: users(:active_member), post_type: :discussion, title: "Post #{i}", body: "Body")
    end

    result = FeedQuery.new(page: 1).call
    assert_equal 25, result[:posts].size
    assert result[:total] > 25
    assert result[:total_pages] > 1

    result_page2 = FeedQuery.new(page: 2).call
    assert result_page2[:posts].size > 0
  end

  test "hot sort excludes posts older than 14 days" do
    old_post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Old", body: "Body")
    old_post.update_columns(published_at: 15.days.ago, status: :published)

    result = FeedQuery.new(sort: "hot").call
    assert_not_includes result[:posts].map(&:id), old_post.id
  end

  test "top sort with day window filters by published_at" do
    day_post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Day", body: "Body")
    old_post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Old2", body: "Body")
    day_post.update_columns(published_at: 6.hours.ago, status: :published)
    old_post.update_columns(published_at: 2.days.ago, status: :published)

    result = FeedQuery.new(sort: "top", window: "day").call
    assert_includes result[:posts].map(&:id), day_post.id
    assert_not_includes result[:posts].map(&:id), old_post.id
  end

  test "type filter limits results" do
    shipped = Post.new(user: users(:active_member), post_type: :shipped, title: "Ship", body: "Body", link_url: "https://example.com")
    shipped.image.attach(io: StringIO.new("image"), filename: "test.png", content_type: "image/png")
    shipped.save!
    shipped.update_column(:status, :published)

    result = FeedQuery.new(types: [ "shipped" ]).call
    assert_includes result[:posts].map(&:id), shipped.id
    assert_not_includes result[:posts].map(&:id), posts(:commented_post).id
  end

  test "tag filter limits results" do
    result = FeedQuery.new(tag: tags(:active_tag).slug).call
    assert_includes result[:posts].map(&:id), posts(:commented_post).id
    assert_not_includes result[:posts].map(&:id), posts(:build_post).id
  end

  test "tag filter ignores archived tags" do
    result = FeedQuery.new(tag: tags(:archived_tag).slug).call

    assert_empty result[:posts]
  end

  test "new sort orders by published_at desc" do
    new_post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Latest", body: "Body")
    result = FeedQuery.new(sort: "new").call
    assert_equal new_post.id, result[:posts].first.id
  end

  test "top sort orders by score desc" do
    top_post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Top", body: "Body")
    top_post.update_columns(score: 100, upvote_count: 100, published_at: 1.day.ago)

    result = FeedQuery.new(sort: "top").call
    assert_equal top_post.id, result[:posts].first.id
  end
end
