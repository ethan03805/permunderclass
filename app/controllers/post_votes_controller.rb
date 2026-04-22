class PostVotesController < ApplicationController
  before_action :require_verified_user!
  before_action :set_post

  def create
    vote = current_user.post_votes.find_or_initialize_by(post: @post)

    if vote.persisted? && vote.value == requested_value
      vote.destroy!
    else
      vote.value = requested_value
      vote.save!
    end

    redirect_to_safe_return_path post_path(@post), anchor: params[:anchor]
  end

  private

  def set_post
    @post = Post.find_by_slugged_id!(params[:post_id])
    raise ActiveRecord::RecordNotFound unless @post.visible_to?(current_user) && !@post.removed?
  end

  def requested_value
    value = params.require(:value).to_i
    raise ActionController::BadRequest unless value.in?([ 1, -1 ])

    value
  end
end
