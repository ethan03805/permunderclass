require "test_helper"

class RateLimitingTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.enabled = true
    Rails.cache.clear
  end

  teardown do
    Rack::Attack.enabled = false
    Rails.cache.clear
  end

  test "sign-up requests are throttled by IP" do
    with_stubbed_turnstile_verification(true) do
      3.times do |index|
        post sign_up_path, params: {
          user: {
            email: "duplicate#{index}@example.com",
            pseudonym: "duplicate#{index}"
          }
        }.merge(spam_check_params(:sign_up)), headers: { "REMOTE_ADDR" => "10.0.0.5" }

        assert_redirected_to sign_in_path
      end

      post sign_up_path, params: {
        user: {
          email: "fourth@example.com",
          pseudonym: "fourth_builder"
        }
      }.merge(spam_check_params(:sign_up)), headers: { "REMOTE_ADDR" => "10.0.0.5" }

      assert_response :too_many_requests
    end
  end

  test "failed sign-in attempts are blocked after the configured limit" do
    10.times do
      post sign_in_path, params: {
        session: {
          email: users(:active_member).email,
          password: "wrong-password"
        }
      }, headers: { "REMOTE_ADDR" => "10.0.0.6" }

      assert_redirected_to sign_in_path
    end

    post sign_in_path, params: {
      session: {
        email: users(:active_member).email,
        password: "wrong-password"
      }
    }, headers: { "REMOTE_ADDR" => "10.0.0.6" }

    assert_response :too_many_requests
  end

  test "post creation is throttled within ten minutes" do
    sign_in_as(users(:active_member))

    post submit_path, params: {
      post: {
        post_type: "discussion",
        title: "First limited post",
        body: "This one should work."
      }
    }.merge(spam_check_params(:submit))

    assert_redirected_to post_path(Post.order(:id).last)

    post submit_path, params: {
      post: {
        post_type: "discussion",
        title: "Second limited post",
        body: "This one should be blocked."
      }
    }.merge(spam_check_params(:submit))

    assert_response :too_many_requests
  end

  test "fresh accounts can only create one post per day even after the ten minute window" do
    user = User.create!(
      pseudonym: "fresh_builder",
      email: "fresh@example.com",
      state: :active,
      email_verified_at: 2.hours.ago
    )

    sign_in_as(user)

    post submit_path, params: {
      post: {
        post_type: "discussion",
        title: "Fresh post one",
        body: "The first post should work."
      }
    }.merge(spam_check_params(:submit))

    assert_response :redirect

    travel 11.minutes do
      post submit_path, params: {
        post: {
          post_type: "discussion",
          title: "Fresh post two",
          body: "The second post should be blocked."
        }
      }.merge(spam_check_params(:submit))
    end

    assert_response :too_many_requests
  end

  test "comment creation is throttled per minute" do
    sign_in_as(users(:active_member))

    6.times do |index|
      post post_comments_path(posts(:discussion_post)), params: {
        comment: { body: "Comment #{index}" },
        comment_sort: "top"
      }

      assert_response :redirect
    end

    post post_comments_path(posts(:discussion_post)), params: {
      comment: { body: "Comment blocked" },
      comment_sort: "top"
    }

    assert_response :too_many_requests
  end

  test "vote mutations are throttled per minute" do
    sign_in_as(users(:active_member))

    30.times do
      post post_vote_path(posts(:discussion_post)), params: {
        value: 1,
        return_to: post_path(posts(:discussion_post))
      }

      assert_response :redirect
    end

    post post_vote_path(posts(:discussion_post)), params: {
      value: 1,
      return_to: post_path(posts(:discussion_post))
    }

    assert_response :too_many_requests
  end

  test "recovery requests are throttled per IP" do
    with_stubbed_turnstile_verification(true) do
      5.times do |index|
        post recover_path,
          params: { recovery: { email: "throttle#{index}@example.com" } },
          headers: { "REMOTE_ADDR" => "10.0.0.7" }

        assert_response :redirect
      end

      post recover_path,
        params: { recovery: { email: "throttle-final@example.com" } },
        headers: { "REMOTE_ADDR" => "10.0.0.7" }

      assert_response :too_many_requests
    end
  end
end
