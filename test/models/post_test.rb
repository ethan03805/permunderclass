require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "fixture posts are valid" do
    assert posts(:commented_post).valid?
    assert posts(:build_post).valid?
    assert posts(:discussion_post).valid?
    assert posts(:removed_post).valid?
  end

  test "title is required and limited to 140 characters" do
    post = posts(:discussion_post)
    post.title = ""
    assert_not post.valid?
    assert_includes post.errors[:title], I18n.t("activerecord.errors.models.post.attributes.title.blank")

    post.title = "a" * 141
    assert_not post.valid?
    assert_includes post.errors[:title], I18n.t("activerecord.errors.models.post.attributes.title.too_long", count: 140)
  end

  test "body is required and limited to 10000 characters" do
    post = posts(:discussion_post)
    post.body = ""
    assert_not post.valid?
    assert_includes post.errors[:body], I18n.t("activerecord.errors.models.post.attributes.body.blank")

    post.body = "a" * 10_001
    assert_not post.valid?
    assert_includes post.errors[:body], I18n.t("activerecord.errors.models.post.attributes.body.too_long", count: 10_000)
  end

  test "link_url must be http or https when present" do
    post = posts(:discussion_post)
    post.link_url = "ftp://example.com"
    assert_not post.valid?
    assert_includes post.errors[:link_url], I18n.t("activerecord.errors.models.post.attributes.link_url.invalid")
  end

  test "discussion post may include link_url" do
    post = posts(:discussion_post)
    post.link_url = "https://example.com/reference"

    assert post.valid?
  end

  test "shipped post requires link_url" do
    post = Post.new(user: users(:active_member), post_type: :shipped, title: "Ship", body: "Body", link_url: "")
    post.image.attach(io: StringIO.new("image"), filename: "test.png", content_type: "image/png")
    assert_not post.valid?
    assert_includes post.errors[:link_url], I18n.t("activerecord.errors.models.post.attributes.link_url.blank")
  end

  test "build post requires build_status" do
    post = Post.new(user: users(:active_member), post_type: :build, title: "Build", body: "Body")
    post.image.attach(io: StringIO.new("image"), filename: "test.png", content_type: "image/png")
    assert_not post.valid?
    assert_includes post.errors[:build_status], I18n.t("activerecord.errors.models.post.attributes.build_status.blank")
  end

  test "shipped post rejects build_status" do
    post = Post.new(user: users(:active_member), post_type: :shipped, title: "Ship", body: "Body", link_url: "https://example.com")
    post.image.attach(io: StringIO.new("image"), filename: "test.png", content_type: "image/png")
    post.build_status = "sharing"
    assert_not post.valid?
    assert_includes post.errors[:build_status], I18n.t("activerecord.errors.models.post.attributes.build_status.present")
  end

  test "tag limit is 3" do
    third_tag = Tag.create!(name: "third")
    fourth_tag = Tag.create!(name: "fourth")
    post = Post.new(user: users(:active_member), post_type: :discussion, title: "Tagged", body: "Body")

    post.tags = [ tags(:active_tag), tags(:archived_tag), third_tag ]
    assert post.valid?

    post.tags = [ tags(:active_tag), tags(:archived_tag), third_tag, fourth_tag ]
    assert_not post.valid?
    assert_includes post.errors[:tags], I18n.t("activerecord.errors.models.post.attributes.tags.too_many")
  end

  test "published_at is set on create when published" do
    user = users(:active_member)
    post = Post.create!(user: user, post_type: :discussion, title: "New", body: "Body", status: :published)
    assert post.published_at.present?
  end

  test "published_at is set on create even when status is removed" do
    post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Draft-like", body: "Body", status: :removed)
    assert post.published_at.present?
  end

  test "published_at is never reset" do
    post = posts(:commented_post)
    original = post.published_at
    post.update!(status: :removed)
    assert_equal original, post.published_at
  end

  test "published_at cannot be changed after publish" do
    post = posts(:commented_post)

    assert_not post.update(published_at: 1.day.ago)
    assert_includes post.errors[:published_at], I18n.t("activerecord.errors.models.post.attributes.published_at.immutable")
  end

  test "edited_at updates on content change" do
    post = posts(:commented_post)
    post.update!(body: "Updated body")
    assert post.edited_at.present?
  end

  test "rewrite requested post requires a rewrite reason" do
    post = posts(:discussion_post)
    post.status = :rewrite_requested
    post.rewrite_reason = ""

    assert_not post.valid?
    assert_includes post.errors[:rewrite_reason], I18n.t("activerecord.errors.models.post.attributes.rewrite_reason.blank")
  end

  test "slug is generated from the title" do
    post = Post.create!(user: users(:active_member), post_type: :discussion, title: "A New Slugged Post", body: "Body")

    assert_equal "a-new-slugged-post", post.slug
  end

  test "linter flags are normalized to a unique array" do
    post = Post.create!(
      user: users(:active_member),
      post_type: :discussion,
      title: "Flags",
      body: "Body",
      linter_flags: [ " hype ", "hype", "" ]
    )

    assert_equal [ "hype" ], post.linter_flags
  end

  test "linter flags must be provided as an array" do
    post = Post.new(
      user: users(:active_member),
      post_type: :discussion,
      title: "Flags",
      body: "Body",
      linter_flags: { unexpected: true }
    )

    assert_not post.valid?
    assert_includes post.errors[:linter_flags], I18n.t("activerecord.errors.models.post.attributes.linter_flags.invalid")
  end

  test "to_param includes the slugged id" do
    assert_equal "#{posts(:commented_post).id}-#{posts(:commented_post).slug}", posts(:commented_post).to_param
  end

  test "hot score is computed from score and published_at" do
    post = Post.new(published_at: Time.at(1_134_028_003), score: 10)
    hot = post.compute_hot_score
    assert_equal 1.0, hot
  end

  test "hot score is zero when published_at is missing" do
    post = Post.new(score: 10)
    assert_equal 0.0, post.compute_hot_score
  end

  test "media rules for shipped require image" do
    post = Post.new(user: users(:active_member), post_type: :shipped, title: "Ship", body: "Body", link_url: "https://example.com")
    assert_not post.valid?
    assert_includes post.errors[:image], I18n.t("activerecord.errors.models.post.attributes.image.required")
  end

  test "media rules for build require image or video" do
    post = Post.new(user: users(:active_member), post_type: :build, title: "Build", body: "Body", build_status: :sharing)
    assert_not post.valid?
    assert_includes post.errors[:base], I18n.t("activerecord.errors.models.post.base.media_required")
  end

  test "media rules for build reject both image and video" do
    post = Post.new(user: users(:active_member), post_type: :build, title: "Build", body: "Body", build_status: :sharing)
    post.image.attach(io: StringIO.new("image"), filename: "test.png", content_type: "image/png")
    post.video.attach(io: StringIO.new("video"), filename: "test.mp4", content_type: "video/mp4")
    assert_not post.valid?
    assert_includes post.errors[:base], I18n.t("activerecord.errors.models.post.base.too_many_media")
  end

  test "media rules for discussion reject attachments" do
    post = Post.new(user: users(:active_member), post_type: :discussion, title: "Discussion", body: "Body")
    post.image.attach(io: StringIO.new("image"), filename: "test.png", content_type: "image/png")
    assert_not post.valid?
    assert_includes post.errors[:image], I18n.t("activerecord.errors.models.post.attributes.image.present")
  end

  test "image validation rejects unsupported content types" do
    post = Post.new(user: users(:active_member), post_type: :shipped, title: "Ship", body: "Body", link_url: "https://example.com")
    post.image.attach(uploaded_large_file(filename: "invalid-image.gif", content_type: "image/gif", size: 256))

    assert_not post.valid?
    assert_includes post.errors[:image], I18n.t("activerecord.errors.models.post.attributes.image.invalid_content_type")
  end

  test "image validation rejects images over 5 MB" do
    post = Post.new(user: users(:active_member), post_type: :shipped, title: "Ship", body: "Body", link_url: "https://example.com")
    post.image.attach(uploaded_large_file(filename: "large-image.png", content_type: "image/png", size: Post::MAX_IMAGE_SIZE + 1))

    assert_not post.valid?
    assert_includes post.errors[:image], I18n.t("activerecord.errors.models.post.attributes.image.too_large")
  end

  test "video validation accepts short h264 mp4 files" do
    post = Post.new(user: users(:active_member), post_type: :build, title: "Build", body: "Body", build_status: :sharing)
    post.video.attach(uploaded_mp4(filename: "valid-h264.mp4", duration: 1, codec: "libx264"))

    assert post.valid?, post.errors.full_messages.to_sentence
  end

  test "video validation rejects non-h264 mp4 files" do
    post = Post.new(user: users(:active_member), post_type: :build, title: "Build", body: "Body", build_status: :sharing)
    post.video.attach(uploaded_mp4(filename: "invalid-codec.mp4", duration: 1, codec: "mpeg4"))

    assert_not post.valid?
    assert_includes post.errors[:video], I18n.t("activerecord.errors.models.post.attributes.video.invalid_codec")
  end

  test "video validation rejects clips longer than 30 seconds" do
    post = Post.new(user: users(:active_member), post_type: :build, title: "Build", body: "Body", build_status: :sharing)
    post.video.attach(uploaded_mp4(filename: "too-long.mp4", duration: 31, codec: "libx264"))

    assert_not post.valid?
    assert_includes post.errors[:video], I18n.t("activerecord.errors.models.post.attributes.video.too_long")
  end

  test "refresh_vote_counters recalculates counts and hot score" do
    post = Post.create!(
      user: users(:active_member),
      post_type: :discussion,
      title: "Epoch",
      body: "Body"
    )
    post.update_columns(published_at: Time.at(Post::HOT_SCORE_EPOCH))

    post.post_votes.create!(user: users(:another_active), value: 1)
    post.post_votes.create!(user: users(:moderator), value: 1)

    post.reload.refresh_vote_counters!
    assert_equal 2, post.upvote_count
    assert_equal 0, post.downvote_count
    assert_equal 2, post.score
    assert_equal Post.compute_hot_score(score: 2, published_at: post.published_at), post.hot_score.to_f
  end

  test "edited_at updates on tag changes" do
    post = posts(:discussion_post)

    PostTag.create!(post: post, tag: tags(:active_tag))

    assert post.reload.edited_at.present?
  end

  test "feed_published scope excludes non-published posts" do
    assert_includes Post.feed_published, posts(:commented_post)
    assert_not_includes Post.feed_published, posts(:rewrite_requested_post)
    assert_not_includes Post.feed_published, posts(:removed_post)
  end

  test "feed_recent scope excludes posts older than 14 days" do
    old = Post.create!(user: users(:active_member), post_type: :discussion, title: "Old scope", body: "Body")
    old.update_columns(published_at: 15.days.ago, status: :published)

    assert_not_includes Post.feed_recent, old
  end

  test "feed_by_tag scope returns posts for a tag slug" do
    assert_includes Post.feed_by_tag("indie"), posts(:commented_post)
    assert_not_includes Post.feed_by_tag("indie"), posts(:build_post)
  end

  test "feed_by_types scope returns posts matching types" do
    result = Post.feed_by_types([ "discussion" ])
    assert_includes result, posts(:commented_post)
  end

  test "rewrite requested posts remain visible on direct url while removed posts do not" do
    assert posts(:rewrite_requested_post).visible_to?(nil)
    assert_not posts(:removed_post).visible_to?(users(:active_member))
    assert posts(:removed_post).visible_to?(users(:moderator))
  end
end
