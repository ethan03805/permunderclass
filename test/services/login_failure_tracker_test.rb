require "test_helper"

class LoginFailureTrackerTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "ip-scoped track increments count and blocked? respects IP_LIMIT" do
    LoginFailureTracker::IP_LIMIT.times { LoginFailureTracker.track("1.1.1.1") }
    assert LoginFailureTracker.blocked?("1.1.1.1")
    refute LoginFailureTracker.blocked?("2.2.2.2")
  end

  test "user-scoped track_user increments count and blocked_user? respects USER_LIMIT" do
    LoginFailureTracker::USER_LIMIT.times { LoginFailureTracker.track_user(42) }
    assert LoginFailureTracker.blocked_user?(42)
    refute LoginFailureTracker.blocked_user?(99)
  end

  test "reset and reset_user clear their own scope only" do
    LoginFailureTracker.track("1.1.1.1")
    LoginFailureTracker.track_user(42)

    LoginFailureTracker.reset("1.1.1.1")

    assert_equal 0, LoginFailureTracker.count("1.1.1.1")
    assert_equal 1, Rails.cache.read("login-failure:user:42").to_i
  end

  test "track tolerates blank arguments" do
    assert_nothing_raised do
      LoginFailureTracker.track(nil)
      LoginFailureTracker.track("")
      LoginFailureTracker.track_user(nil)
    end
  end
end
