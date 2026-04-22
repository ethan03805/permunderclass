ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "active_job/test_helper"
require "base64"
require "fileutils"
require "rack/test"
require "securerandom"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    setup do
      Rails.cache.clear
      Rack::Attack.enabled = false if defined?(Rack::Attack)
    end
  end
end

module AuthenticationTestHelper
  def sign_in_as(user, password: "password123")
    post sign_in_path, params: {
      session: {
        email: user.email,
        password: password
      }
    }
  end

  def with_env(overrides)
    original = overrides.to_h { |key, _value| [ key, ENV[key] ] }

    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      ENV[key] = value
    end
  end

  def spam_check_params(context, started_at: 10.seconds.ago, honeypot: "")
    {
      spam_check: {
        website: honeypot,
        form_started_token: SpamCheck.form_token_for(context, now: started_at)
      }
    }
  end
end

module MediaTestHelper
  TINY_PNG_BASE64 = <<~BASE64.delete("\n")
    iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9sWwaP8AAAAASUVORK5CYII=
  BASE64

  def uploaded_png(filename: "test.png")
    path = media_fixture_path(filename)
    return Rack::Test::UploadedFile.new(path, "image/png", true) if path.exist?

    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, Base64.decode64(TINY_PNG_BASE64))
    Rack::Test::UploadedFile.new(path, "image/png", true)
  end

  def uploaded_large_file(filename:, content_type:, size:)
    path = media_fixture_path(filename)
    return Rack::Test::UploadedFile.new(path, content_type, true) if path.exist?

    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, "a" * size)
    Rack::Test::UploadedFile.new(path, content_type, true)
  end

  def uploaded_mp4(filename:, duration:, codec:)
    path = media_fixture_path(filename)
    return Rack::Test::UploadedFile.new(path, "video/mp4", true) if path.exist?

    FileUtils.mkdir_p(path.dirname)
    command = [
      "ffmpeg",
      "-loglevel", "error",
      "-f", "lavfi",
      "-i", "color=c=black:s=160x120:d=#{duration}",
      "-an",
      "-c:v", codec,
      "-pix_fmt", "yuv420p",
      "-movflags", "+faststart",
      "-y",
      path.to_s
    ]

    raise "ffmpeg failed creating #{filename}" unless system(*command, out: File::NULL, err: File::NULL)

    Rack::Test::UploadedFile.new(path, "video/mp4", true)
  end

  def ffprobe_available?
    system("command -v ffprobe >/dev/null 2>&1", out: File::NULL, err: File::NULL)
  end

  private

  def media_fixture_path(filename)
    Rails.root.join("tmp/test-media/#{filename}")
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationTestHelper
  include ActiveJob::TestHelper
  include MediaTestHelper
end

class ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include MediaTestHelper
end
