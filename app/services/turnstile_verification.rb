require "json"
require "net/http"

class TurnstileVerification
  VERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

  def initialize(token:, remote_ip:, secret_key: ENV.fetch("TURNSTILE_SECRET_KEY", nil), http_client: Net::HTTP)
    @http_client = http_client
    @remote_ip = remote_ip
    @secret_key = secret_key
    @token = token
  end

  def verified?
    return true if skip_verification?
    return false if token.blank? || secret_key.blank?

    response = http_client.post_form(VERIFY_URI, {
      "remoteip" => remote_ip,
      "response" => token,
      "secret" => secret_key
    })

    JSON.parse(response.body).fetch("success", false)
  rescue JSON::ParserError, StandardError
    false
  end

  private

  attr_reader :http_client, :remote_ip, :secret_key, :token

  def skip_verification?
    secret_key.blank? && !Rails.env.production?
  end
end
