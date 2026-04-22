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

  def report_reason_labels
    t("reports.reason_codes")
  end

  def moderator_action_labels
    t("moderation.action_labels")
  end

  def reportable_by_current_user?(target)
    return false unless current_user&.active? && current_user.email_verified?

    case target
    when User
      current_user != target
    when Post
      current_user != target.user && !target.removed?
    when Comment
      current_user != target.user && !target.removed? && !target.post.removed?
    else
      !target.respond_to?(:user) || current_user != target.user
    end
  end

  def moderation_target_path(target)
    case target
    when Post
      post_path(target)
    when Comment
      post_path(target.post, anchor: "comment-#{target.id}")
    when User
      mod_user_path(target)
    when Tag
      mod_tags_path(anchor: "tag-#{target.id}")
    when Report
      mod_report_path(target)
    end
  end

  def moderation_target_label(target)
    case target
    when Post
      target.title
    when Comment
      truncate(target.body, length: 80)
    when User
      target.pseudonym
    when Tag
      target.name
    when Report
      t("reports.labels.report_number", id: target.id)
    end
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

  def comment_sort_labels
    t("comments.sorts").slice("top", "new", "controversial")
  end
end
