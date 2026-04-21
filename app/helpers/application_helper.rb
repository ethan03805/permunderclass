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

  def submit_nav_visible?
    current_user&.active?
  end

  def post_linter_messages
    t("posts.linter.flags")
  end

  def post_type_labels
    t("post_types")
  end

  def build_status_labels
    t("build_statuses")
  end
end
