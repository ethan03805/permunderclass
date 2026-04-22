class CommentsController < ApplicationController
  before_action :require_verified_user!
  before_action :set_post

  def create
    @comment = current_user.comments.build(comment_params.except(:parent_id))
    @comment.post = @post
    @comment.parent = selected_parent_comment if selected_parent_comment.present?

    if @comment.save
      redirect_to post_path(@post, comment_sort: requested_comment_sort, anchor: comment_anchor(@comment)),
        notice: t("comments.notices.created")
    else
      prepare_post_detail_state
      render "posts/show", status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = Post.includes(:tags, :user, image_attachment: :blob, video_attachment: :blob).find_by_slugged_id!(params[:post_id])
    raise ActiveRecord::RecordNotFound unless @post.visible_to?(current_user) && !@post.removed?
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def selected_parent_comment
    return @selected_parent_comment if defined?(@selected_parent_comment)
    return @selected_parent_comment = nil if comment_params[:parent_id].blank?

    @selected_parent_comment = @post.comments.find(comment_params[:parent_id]).tap do |comment|
      raise ActiveRecord::RecordNotFound if comment.removed?
    end
  end

  def requested_comment_sort
    @requested_comment_sort ||= CommentThreadQuery.new(post: @post, sort: params[:comment_sort]).sort
  end

  def prepare_post_detail_state
    thread = CommentThreadQuery.new(post: @post, sort: requested_comment_sort).call

    @comment_thread = thread[:comments_by_parent]
    @comment_sort = thread[:sort]
    @post_vote_value = current_user.post_votes.find_by(post: @post)&.value
    @comment_vote_values = current_user.comment_votes.where(comment_id: thread[:comment_ids]).pluck(:comment_id, :value).to_h
    @new_comment = @comment.parent_id.present? ? Comment.new(post: @post) : @comment
    @reply_comment = @comment.parent_id.present? ? @comment : nil
  end

  def comment_anchor(comment)
    "comment-#{comment.id}"
  end
end
