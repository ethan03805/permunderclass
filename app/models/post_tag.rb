class PostTag < ApplicationRecord
  belongs_to :post
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :post_id }
  validate :post_tag_limit

  before_create :enforce_post_tag_limit!
  after_create :touch_post_edited_at
  after_destroy :touch_post_edited_at

  private

  def post_tag_limit
    return if post.blank?

    existing_tag_count = current_tag_count
    return unless existing_tag_count >= Post::MAX_TAGS

    errors.add(:post, :too_many)
  end

  def enforce_post_tag_limit!
    return if post.blank? || !post.persisted?

    post.with_lock do
      next if current_tag_count < Post::MAX_TAGS

      errors.add(:post, :too_many)
      throw :abort
    end
  end

  def touch_post_edited_at
    return if post.blank? || !post.persisted? || post.saved_change_to_id?

    post.touch(:edited_at)
  end

  def current_tag_count
    existing_tag_count = post.post_tags.where.not(id: id).count
    if post.post_tags.loaded?
      existing_tag_count -= post.post_tags.count { |post_tag| post_tag != self && post_tag.marked_for_destruction? }
    end

    existing_tag_count
  end
end
