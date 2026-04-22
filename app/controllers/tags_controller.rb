class TagsController < ApplicationController
  after_action :set_anonymous_cache_headers, only: :show

  def show
    @tag = Tag.active.find_by!(slug: params[:slug])
    @query = FeedQuery.new(feed_params.merge(tag: @tag.slug))
    @result = @query.call
    @posts = @result[:posts]
    @post_vote_values = current_user.present? ? current_user.post_votes.where(post_id: @posts.map(&:id)).pluck(:post_id, :value).to_h : {}
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: t("tags.not_found")
  end

  private

  def feed_params
    params.permit(:sort, :window, :page, types: [])
  end

  def set_anonymous_cache_headers
    enable_anonymous_edge_cache!
  end
end
