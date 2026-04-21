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
end
