class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :turnstile_site_key, :spam_protection_form_token

  private

  def turnstile_site_key
    ENV.fetch("TURNSTILE_SITE_KEY", "").presence
  end

  def spam_protection_form_token(context)
    SpamCheck.form_token_for(context)
  end

  def enable_anonymous_edge_cache!(max_age: 60, shared_max_age: 300)
    return unless request.get? && current_user.blank? && response.successful?

    response.headers["Cache-Control"] = "public, max-age=#{max_age}, s-maxage=#{shared_max_age}, stale-while-revalidate=30"
  end

  def spam_check_result_for(context)
    SpamCheck.new(
      context: context,
      honeypot_value: spam_check_params[:website],
      form_started_token: spam_check_params[:form_started_token]
    ).call
  end

  def redirect_to_safe_return_path(fallback_location, anchor: nil, **options)
    location = safe_return_path(params[:return_to]) || fallback_location
    location = "#{location}##{anchor}" if anchor.present?

    redirect_to location, **options
  end

  def safe_return_path(value)
    path = value.to_s
    return if path.blank?
    return if !path.start_with?("/") || path.start_with?("//") || path.include?("\n")

    path
  end

  def spam_check_params
    params.fetch(:spam_check, {}).permit(:website, :form_started_token)
  end
end
