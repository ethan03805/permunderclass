class HomeController < ApplicationController
  after_action :set_anonymous_cache_headers, only: :index

  def index
    @query = FeedQuery.new(feed_params)
    @result = @query.call
    @posts = @result[:posts]
    @post_vote_values = current_user.present? ? current_user.post_votes.where(post_id: @posts.map(&:id)).pluck(:post_id, :value).to_h : {}
  end

  private

  def feed_params
    params.permit(:sort, :window, :tag, :page, types: [])
  end

  def set_anonymous_cache_headers
    enable_anonymous_edge_cache!
  end
end
