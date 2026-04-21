require "test_helper"

class PostTagTest < ActiveSupport::TestCase
  test "fixture post tag is valid" do
    assert post_tags(:shipped_tagging).valid?
  end

  test "duplicate tag on same post is not allowed" do
    existing = post_tags(:shipped_tagging)
    pt = PostTag.new(post: existing.post, tag: existing.tag)
    assert_not pt.valid?
    assert_includes pt.errors[:tag_id], I18n.t("errors.messages.taken")
  end

  test "a post cannot have more than 3 tags" do
    post = posts(:discussion_post)
    third_tag = Tag.create!(name: "third tag")
    fourth_tag = Tag.create!(name: "fourth tag")

    PostTag.create!(post: post, tag: tags(:active_tag))
    PostTag.create!(post: post, tag: tags(:archived_tag))
    PostTag.create!(post: post, tag: third_tag)

    post_tag = PostTag.new(post: post, tag: fourth_tag)

    assert_not post_tag.valid?
    assert_includes post_tag.errors[:post], I18n.t("activerecord.errors.models.post_tag.attributes.post.too_many")
  end

  test "replacing one of 3 tags remains valid" do
    post = posts(:discussion_post)
    third_tag = Tag.create!(name: "third tag")
    replacement_tag = Tag.create!(name: "replacement tag")

    PostTag.create!(post: post, tag: tags(:active_tag))
    PostTag.create!(post: post, tag: tags(:archived_tag))
    PostTag.create!(post: post, tag: third_tag)

    post.tags = [ tags(:active_tag), tags(:archived_tag), replacement_tag ]

    assert post.save
    assert_equal [ "indie", "legacy", "replacement-tag" ], post.tags.reload.map(&:slug).sort
  end
end
