class Rack::Attack
  self.cache.store = Rails.cache
  self.enabled = !Rails.env.test?

  throttle("sign_up/ip", limit: 3, period: 1.hour) do |request|
    request.ip if request.post? && request.path == "/sign-up"
  end

  blocklist("login_failures/ip") do |request|
    request.post? && request.path == "/sign-in" && LoginFailureTracker.blocked?(request.ip)
  end

  throttle("post_creations/user/ten_minutes", limit: 1, period: 10.minutes) do |request|
    authenticated_user_id(request) if post_creation_request?(request)
  end

  throttle("post_creations/user/day", limit: 2, period: 24.hours) do |request|
    authenticated_user_id(request) if post_creation_request?(request)
  end

  throttle("post_creations/fresh_user/day", limit: 1, period: 24.hours) do |request|
    fresh_user_id(request) if post_creation_request?(request)
  end

  throttle("comment_creations/user/minute", limit: 6, period: 1.minute) do |request|
    authenticated_user_id(request) if comment_creation_request?(request)
  end

  throttle("comment_creations/user/hour", limit: 60, period: 1.hour) do |request|
    authenticated_user_id(request) if comment_creation_request?(request)
  end

  throttle("comment_creations/fresh_user/day", limit: 20, period: 24.hours) do |request|
    fresh_user_id(request) if comment_creation_request?(request)
  end

  throttle("vote_mutations/user/minute", limit: 30, period: 1.minute) do |request|
    authenticated_user_id(request) if vote_mutation_request?(request)
  end

  throttle("vote_mutations/user/day", limit: 500, period: 24.hours) do |request|
    authenticated_user_id(request) if vote_mutation_request?(request)
  end

  throttle("vote_mutations/fresh_user/day", limit: 100, period: 24.hours) do |request|
    fresh_user_id(request) if vote_mutation_request?(request)
  end

  self.blocklisted_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain; charset=utf-8" }, [ I18n.t("rate_limits.exceeded") ] ]
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain; charset=utf-8" }, [ I18n.t("rate_limits.exceeded") ] ]
  end

  def self.authenticated_user_id(request)
    request.session["user_id"] || request.session[:user_id]
  rescue StandardError
    nil
  end

  def self.comment_creation_request?(request)
    request.post? && request.path.match?(%r{\A/posts/[^/]+/comments\z})
  end

  def self.post_creation_request?(request)
    request.post? && request.path == "/submit"
  end

  def self.vote_mutation_request?(request)
    request.post? && (request.path.match?(%r{\A/posts/[^/]+/vote\z}) || request.path.match?(%r{\A/comments/\d+/vote\z}))
  end

  def self.fresh_user_id(request)
    user_id = authenticated_user_id(request)
    return if user_id.blank?

    user = User.select(:id, :state, :email_verified_at).find_by(id: user_id)
    return unless user&.fresh_account?

    user.id
  end
end

Rails.application.config.middleware.use Rack::Attack
