module ApplicationHelper
  def page_title(page_name = nil)
    [ page_name.presence, t("app.title") ].compact.join(" · ")
  end

  def nav_link_class(path)
    classes = [ "site-nav__link" ]
    classes << "is-active" if current_page?(path)
    classes.join(" ")
  end

  def feed_params_for(overrides = {})
    request.query_parameters.symbolize_keys.merge(overrides)
  end

  def post_permalink_path(post)
    "/posts/#{post.id}-#{post.slug}"
  end
end
