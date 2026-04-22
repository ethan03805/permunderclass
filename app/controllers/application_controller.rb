class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :turnstile_site_key

  private

  def turnstile_site_key
    ENV.fetch("TURNSTILE_SITE_KEY", "").presence
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
end
