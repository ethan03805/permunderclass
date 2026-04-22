class HomeController < ApplicationController
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
end
