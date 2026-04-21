class CommentVote < ApplicationRecord
  belongs_to :user
  belongs_to :comment

  validates :value, inclusion: { in: [ 1, -1 ] }
  validates :user_id, uniqueness: { scope: :comment_id }

  after_create :refresh_comment_counters
  after_update :refresh_comment_counters, if: :saved_change_to_value?
  after_destroy :refresh_comment_counters

  private

  def refresh_comment_counters
    comment.refresh_vote_counters!
  end
end
