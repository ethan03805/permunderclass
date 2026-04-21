class HomeController < ApplicationController
  def index
    @query = FeedQuery.new(feed_params)
    @result = @query.call
    @posts = @result[:posts]
  end

  private

  def feed_params
    params.permit(:sort, :window, :tag, :page, types: [])
  end
end
