require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "fixture tag is valid" do
    assert tags(:active_tag).valid?
  end

  test "name is required and unique" do
    tag = Tag.new(name: "", slug: "new")
    assert_not tag.valid?
    assert_includes tag.errors[:name], I18n.t("activerecord.errors.models.tag.attributes.name.blank")

    tag.name = tags(:active_tag).name.upcase
    assert_not tag.valid?
    assert_includes tag.errors[:name], I18n.t("activerecord.errors.models.tag.attributes.name.taken")
  end

  test "slug is required and unique" do
    generated_tag = Tag.new(name: "new", slug: "")
    assert generated_tag.valid?
    assert_equal "new", generated_tag.slug

    duplicate_slug = Tag.new(name: "different", slug: tags(:active_tag).slug.upcase)
    assert_not duplicate_slug.valid?
    assert_includes duplicate_slug.errors[:slug], I18n.t("activerecord.errors.models.tag.attributes.slug.taken")
  end

  test "state defaults to active" do
    tag = Tag.new(name: "fresh", slug: "fresh")
    assert tag.active?
  end

  test "slug is generated from the name" do
    tag = Tag.create!(name: "Builder Tools")

    assert_equal "builder-tools", tag.slug
  end
end
