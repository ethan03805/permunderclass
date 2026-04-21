class TagsController < ApplicationController
  def show
    @tag = Tag.active.find_by!(slug: params[:slug])
    @query = FeedQuery.new(feed_params.merge(tag: @tag.slug))
    @result = @query.call
    @posts = @result[:posts]
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: t("tags.not_found")
  end

  private

  def feed_params
    params.permit(:sort, :window, :page, types: [])
  end
end
