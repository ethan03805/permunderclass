class Post < ApplicationRecord
  MAX_TAGS = 3
  HOT_SCORE_EPOCH = 1_134_028_003

  attr_accessor :raw_linter_flags_input

  belongs_to :user
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_many :comments, dependent: :restrict_with_error
  has_many :post_votes, dependent: :destroy
  has_many :reports, as: :target, dependent: :restrict_with_error
  has_many :moderator_actions, as: :target, dependent: :restrict_with_error

  has_one_attached :image, dependent: :purge_later
  has_one_attached :video, dependent: :purge_later

  enum :post_type, { shipped: 0, build: 1, discussion: 2 }, validate: true, prefix: true
  enum :status, { published: 0, rewrite_requested: 1, removed: 2 }, default: :published, validate: true
  enum :build_status, { sharing: 0, want_feedback: 1, looking_for_testers: 2 }, validate: { allow_nil: true }

  validates :title, presence: true, length: { maximum: 140 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :link_url, format: { with: /\Ahttps?:\/\/.*\z/i }, allow_blank: true
  validates :slug, uniqueness: { case_sensitive: false }, allow_blank: true
  validate :type_specific_rules
  validate :media_structure_rules
  validate :tag_count_within_limit
  validate :rewrite_reason_required_for_rewrite_requested
  validate :linter_flags_must_be_an_array
  validate :published_at_immutable, on: :update

  before_validation :normalize_fields
  before_validation :initialize_cached_fields, on: :create
  before_validation :assign_slug, if: :should_assign_slug?
  before_validation :normalize_linter_flags
  before_validation :set_rewrite_requested_at
  before_validation :sync_hot_score, if: :published_at?
  before_create :apply_publication_fields
  before_update :touch_edited_at, if: :tracked_edit?

  scope :feed_published, -> { where(status: :published) }
  scope :feed_recent, -> { where(published_at: 14.days.ago..) }
  scope :feed_hot, -> { feed_published.feed_recent.order(hot_score: :desc, published_at: :desc) }
  scope :feed_new, -> { feed_published.order(published_at: :desc) }
  scope :feed_top, -> { feed_published.order(score: :desc, upvote_count: :desc, published_at: :desc) }
  scope :feed_by_window, ->(window) {
    case window.to_s
    when "day" then where(published_at: 1.day.ago..)
    when "week" then where(published_at: 7.days.ago..)
    when "month" then where(published_at: 30.days.ago..)
    else all
    end
  }
  scope :feed_by_types, ->(types) {
    types = Array(types).map(&:to_s).select { |t| post_types.keys.include?(t) }
    types.any? ? where(post_type: types) : all
  }
  scope :feed_by_tag, ->(tag) {
    slug = tag.to_s.strip.downcase
    joins(:tags).merge(Tag.active).where(tags: { slug: slug })
  }

  def self.compute_hot_score(score:, published_at:)
    PostRanking.compute(score: score, published_at: published_at)
  end

  def compute_hot_score
    PostRanking.compute(score: score.to_i, published_at: published_at)
  end

  def linter_flags=(value)
    self.raw_linter_flags_input = value if raw_linter_flags_input.nil?
    super
  end

  def refresh_vote_counters!
    with_lock do
      counts = post_votes.group(:value).count
      up = counts[1].to_i
      down = counts[-1].to_i
      new_score = up - down

      update_columns(
        upvote_count: up,
        downvote_count: down,
        score: new_score,
        hot_score: self.class.compute_hot_score(score: new_score, published_at: published_at)
      )
    end
  end

  def refresh_report_count!
    with_lock do
      update_columns(report_count: reports.open.count)
    end
  end

  private

  def tracked_edit?
    will_save_change_to_title? || will_save_change_to_body? || will_save_change_to_link_url? ||
      will_save_change_to_build_status? || will_save_change_to_post_type? ||
      will_save_change_to_status? || will_save_change_to_rewrite_reason? ||
      attachment_changes.present?
  end

  def touch_edited_at
    self.edited_at = Time.current
  end

  def normalize_fields
    self.title = title.to_s.strip.presence
    self.body = body.to_s.strip.presence
    self.link_url = link_url.to_s.strip.presence
    self.rewrite_reason = rewrite_reason.to_s.strip.presence
  end

  def initialize_cached_fields
    self.upvote_count = 0
    self.downvote_count = 0
    self.score = 0
    self.comment_count = 0
    self.report_count = 0
    self.hot_score = 0.0
  end

  def should_assign_slug?
    title.present? && (slug.blank? || (will_save_change_to_title? && !will_save_change_to_slug?))
  end

  def assign_slug
    base_slug = title.to_s.parameterize.presence || "post"
    candidate = base_slug
    suffix = 2

    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def normalize_linter_flags
    self.linter_flags = Array(linter_flags).filter_map { |flag| flag.to_s.strip.presence }.uniq
  end

  def apply_publication_fields
    self.published_at = Time.current
    self.hot_score = self.class.compute_hot_score(score: score.to_i, published_at: published_at)
  end

  def set_rewrite_requested_at
    return unless rewrite_requested? && (new_record? || will_save_change_to_status?)

    self.rewrite_requested_at = Time.current
  end

  def sync_hot_score
    self.hot_score = self.class.compute_hot_score(score: score.to_i, published_at: published_at)
  end

  def type_specific_rules
    case post_type
    when "shipped"
      errors.add(:link_url, :blank) if link_url.blank?
      errors.add(:build_status, :present) if build_status.present?
    when "build"
      errors.add(:build_status, :blank) if build_status.blank?
    when "discussion"
      errors.add(:build_status, :present) if build_status.present?
    end
  end

  def media_structure_rules
    case post_type
    when "shipped"
      errors.add(:image, :required) unless image.attached?
      errors.add(:video, :present) if video.attached?
    when "build"
      if image.attached? && video.attached?
        errors.add(:base, :too_many_media)
      elsif !image.attached? && !video.attached?
        errors.add(:base, :media_required)
      end
    when "discussion"
      errors.add(:image, :present) if image.attached?
      errors.add(:video, :present) if video.attached?
    end
  end

  def tag_count_within_limit
    taggings = post_tags.reject(&:marked_for_destruction?)
    if taggings.size > MAX_TAGS
      errors.add(:tags, :too_many)
    end
  end

  def rewrite_reason_required_for_rewrite_requested
    return unless rewrite_requested? && rewrite_reason.blank?

    errors.add(:rewrite_reason, :blank)
  end

  def linter_flags_must_be_an_array
    raw_linter_flags = raw_linter_flags_input.nil? ? linter_flags : raw_linter_flags_input
    return if raw_linter_flags.blank? || raw_linter_flags.is_a?(Array)

    errors.add(:linter_flags, :invalid)
  end

  def published_at_immutable
    return unless will_save_change_to_published_at?

    errors.add(:published_at, :immutable)
  end
end
