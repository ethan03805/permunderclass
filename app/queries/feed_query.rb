class FeedQuery
  PER_PAGE = 25

  SORTS = %w[hot new top].freeze
  WINDOWS = %w[day week month all].freeze
  TYPES = Post.post_types.keys.freeze

  def initialize(params = {})
    @params = params
  end

  def call
    scope = Post.feed_published.includes(:user, :tags)
    scope = apply_sort(scope)
    scope = apply_window(scope)
    scope = apply_types(scope)
    scope = apply_tag(scope)
    scope = scope.distinct
    paginate(scope)
  end

  def sort
    SORTS.include?(@params[:sort].to_s) ? @params[:sort].to_s : "hot"
  end

  def window
    WINDOWS.include?(@params[:window].to_s) ? @params[:window].to_s : "all"
  end

  def types
    Array(@params[:types]).map(&:to_s).select { |t| TYPES.include?(t) }
  end

  def tag_slug
    @params[:tag].to_s.presence
  end

  def page
    [ @params[:page].to_i, 1 ].max
  end

  private

  def apply_sort(scope)
    case sort
    when "hot" then scope.feed_hot
    when "new" then scope.feed_new
    when "top" then scope.feed_top
    else scope
    end
  end

  def apply_window(scope)
    return scope unless sort == "top" && window != "all"
    scope.feed_by_window(window)
  end

  def apply_types(scope)
    return scope if types.empty?
    scope.feed_by_types(types)
  end

  def apply_tag(scope)
    return scope unless tag_slug.present?
    scope.feed_by_tag(tag_slug)
  end

  def paginate(scope)
    total = scope.count
    offset = (page - 1) * PER_PAGE
    total_pages = (total.to_f / PER_PAGE).ceil

    {
      posts: scope.limit(PER_PAGE).offset(offset).to_a,
      total: total,
      page: page,
      per_page: PER_PAGE,
      total_pages: total_pages
    }
  end
end
