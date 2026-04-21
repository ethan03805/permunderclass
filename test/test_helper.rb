ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
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
end

class ActionDispatch::IntegrationTest
  include AuthenticationTestHelper
end
