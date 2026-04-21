class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :comment_votes, dependent: :destroy
  has_many :reports, as: :target, dependent: :restrict_with_error
  has_many :moderator_actions, as: :target, dependent: :restrict_with_error

  enum :status, { published: 0, removed: 1 }, default: :published, validate: true

  validates :body, presence: true, length: { maximum: 5000 }
  validates :depth, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 8 }
  validate :parent_must_belong_to_same_post
  validate :parent_cannot_be_self
  validate :parent_cannot_be_descendant, on: :update

  before_validation :initialize_cached_fields, on: :create
  before_validation :set_depth
  before_update :touch_edited_at, if: :tracked_edit?
  after_create :increment_parent_reply_count, if: :parent_id?
  after_destroy :decrement_parent_reply_count, if: :parent_id?
  after_create :increment_post_comment_count
  after_destroy :decrement_post_comment_count

  def refresh_vote_counters!
    with_lock do
      counts = comment_votes.group(:value).count
      up = counts[1].to_i
      down = counts[-1].to_i
      update_columns(upvote_count: up, downvote_count: down, score: up - down)
    end
  end

  def refresh_report_count!
    with_lock do
      update_columns(report_count: reports.open.count)
    end
  end

  private

  def initialize_cached_fields
    self.upvote_count = 0
    self.downvote_count = 0
    self.score = 0
    self.reply_count = 0
    self.report_count = 0
  end

  def set_depth
    self.depth = parent ? parent.depth + 1 : 0
  end

  def tracked_edit?
    will_save_change_to_body? || will_save_change_to_status?
  end

  def touch_edited_at
    self.edited_at = Time.current
  end

  def increment_parent_reply_count
    Comment.update_counters(parent.id, reply_count: 1)
  end

  def decrement_parent_reply_count
    Comment.update_counters(parent.id, reply_count: -1)
  end

  def increment_post_comment_count
    Post.update_counters(post.id, comment_count: 1)
  end

  def decrement_post_comment_count
    Post.update_counters(post.id, comment_count: -1)
  end

  def parent_must_belong_to_same_post
    return if parent.blank? || post.blank? || parent.post_id == post_id

    errors.add(:parent, :invalid_post)
  end

  def parent_cannot_be_self
    return unless parent_id.present? && id.present? && parent_id == id

    errors.add(:parent, :self_reference)
  end

  def parent_cannot_be_descendant
    return if parent.blank? || id.blank?

    current_ancestor = parent
    seen_comment_ids = []

    while current_ancestor.present?
      if current_ancestor.id == id
        errors.add(:parent, :descendant)
        break
      end

      break if current_ancestor.id.in?(seen_comment_ids)

      seen_comment_ids << current_ancestor.id
      current_ancestor = current_ancestor.parent
    end
  end
end
