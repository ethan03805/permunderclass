class Tag < ApplicationRecord
  enum :state, { active: 0, archived: 1 }, default: :active, validate: true

  has_many :post_tags, dependent: :restrict_with_error
  has_many :posts, through: :post_tags
  has_many :moderator_actions, as: :target, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_identifiers
  before_validation :assign_slug, if: :should_assign_slug?

  private

  def normalize_identifiers
    self.name = name.to_s.strip.presence
    self.slug = slug.to_s.strip.downcase.presence
  end

  def should_assign_slug?
    name.present? && (slug.blank? || (will_save_change_to_name? && !will_save_change_to_slug?))
  end

  def assign_slug
    base_slug = name.to_s.parameterize.presence || "tag"
    candidate = base_slug
    suffix = 2

    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
