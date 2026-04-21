class PostVote < ApplicationRecord
  belongs_to :user
  belongs_to :post

  validates :value, inclusion: { in: [ 1, -1 ] }
  validates :user_id, uniqueness: { scope: :post_id }

  after_create :refresh_post_counters
  after_update :refresh_post_counters, if: :saved_change_to_value?
  after_destroy :refresh_post_counters

  private

  def refresh_post_counters
    post.refresh_vote_counters!
  end
end
