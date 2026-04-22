require "test_helper"

class ProfilePagesTest < ActionDispatch::IntegrationTest
  test "profile shows visible post history including rewrite requested posts" do
    get profile_path(users(:active_member).pseudonym)

    assert_response :success
    assert_select "h1", users(:active_member).pseudonym
    assert_select ".activity-item", text: /#{Regexp.escape(posts(:commented_post).title)}/
    assert_select ".activity-item", text: /#{Regexp.escape(posts(:rewrite_requested_post).title)}/
    assert_select ".activity-item", text: /#{Regexp.escape(posts(:removed_post).title)}/, count: 0
  end

  test "profile filters posts by type" do
    shipped_post = Post.new(
      user: users(:active_member),
      post_type: :shipped,
      title: "Shipped profile item",
      body: "A launched thing.",
      link_url: "https://example.com/shipped"
    )
    shipped_post.image.attach(uploaded_png(filename: "profile-shipped.png"))
    shipped_post.save!

    build_post = Post.new(
      user: users(:active_member),
      post_type: :build,
      title: "Build profile item",
      body: "An in-progress thing.",
      build_status: :sharing
    )
    build_post.image.attach(uploaded_png(filename: "profile-build.png"))
    build_post.save!

    get profile_path(users(:active_member).pseudonym), params: { post_type: "build" }

    assert_response :success
    assert_select ".activity-item", text: /Build profile item/
    assert_select ".activity-item", text: /Shipped profile item/, count: 0
  end

  test "profile shows comment history" do
    get profile_path(users(:active_member).pseudonym), params: { view: "comments" }

    assert_response :success
    assert_select ".activity-item", text: /#{Regexp.escape(comments(:reply_comment).body)}/
    assert_select "a[href='#{post_path(comments(:reply_comment).post, anchor: "comment-#{comments(:reply_comment).id}")}']"
  end

  test "moderators can see removed posts on profiles" do
    sign_in_as(users(:moderator))

    get profile_path(users(:active_member).pseudonym)

    assert_response :success
    assert_select ".activity-item", text: /#{Regexp.escape(posts(:removed_post).title)}/
  end

  test "static pages render from locale content" do
    {
      about_path => I18n.t("static_pages.about.title"),
      rules_path => I18n.t("static_pages.rules.title"),
      faq_path => I18n.t("static_pages.faq.title"),
      privacy_path => I18n.t("static_pages.privacy.title"),
      terms_path => I18n.t("static_pages.terms.title")
    }.each do |path, title|
      get path

      assert_response :success
      assert_select "h1", title
    end
  end
end
