require "test_helper"

class TurnstileVerificationTest < ActiveSupport::TestCase
  Response = Struct.new(:body)

  test "verification is skipped outside production when secret is missing" do
    service = TurnstileVerification.new(token: nil, remote_ip: "127.0.0.1", secret_key: nil)

    assert service.verified?
  end

  test "blank token fails when a secret is provided" do
    service = TurnstileVerification.new(token: nil, remote_ip: "127.0.0.1", secret_key: "secret")

    assert_not service.verified?
  end

  test "successful cloudflare response passes verification" do
    http_client = Struct.new(:response_body, :captured_uri, :captured_params) do
      def post_form(uri, params)
        self.captured_uri = uri
        self.captured_params = params
        Response.new(response_body)
      end
    end

    client = http_client.new('{"success":true}')

    service = TurnstileVerification.new(
      token: "token",
      remote_ip: "127.0.0.1",
      secret_key: "secret",
      http_client: client
    )

    assert service.verified?
    assert_equal URI("https://challenges.cloudflare.com/turnstile/v0/siteverify"), client.captured_uri
    assert_equal(
      {
        "remoteip" => "127.0.0.1",
        "response" => "token",
        "secret" => "secret"
      },
      client.captured_params
    )
  end

  test "unsuccessful cloudflare response fails verification" do
    http_client = Struct.new(:response_body) do
      def post_form(_uri, _params)
        Response.new(response_body)
      end
    end

    service = TurnstileVerification.new(
      token: "token",
      remote_ip: "127.0.0.1",
      secret_key: "secret",
      http_client: http_client.new('{"success":false}')
    )

    assert_not service.verified?
  end

  test "invalid json fails verification" do
    http_client = Struct.new(:response_body) do
      def post_form(_uri, _params)
        Response.new(response_body)
      end
    end

    service = TurnstileVerification.new(
      token: "token",
      remote_ip: "127.0.0.1",
      secret_key: "secret",
      http_client: http_client.new("not-json")
    )

    assert_not service.verified?
  end
end
