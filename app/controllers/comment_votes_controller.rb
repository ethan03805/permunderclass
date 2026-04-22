class CommentVotesController < ApplicationController
  before_action :require_verified_user!
  before_action :set_comment

  def create
    vote = current_user.comment_votes.find_or_initialize_by(comment: @comment)

    if vote.persisted? && vote.value == requested_value
      vote.destroy!
    else
      vote.value = requested_value
      vote.save!
    end

    redirect_to_safe_return_path post_path(@comment.post), anchor: comment_anchor
  end

  private

  def set_comment
    @comment = Comment.includes(:post).find(params[:comment_id])
    raise ActiveRecord::RecordNotFound if @comment.removed?
    raise ActiveRecord::RecordNotFound unless @comment.post.visible_to?(current_user) && !@comment.post.removed?
  end

  def requested_value
    value = params.require(:value).to_i
    raise ActionController::BadRequest unless value.in?([ 1, -1 ])

    value
  end

  def comment_anchor
    "comment-#{@comment.id}"
  end
end
