require "test_helper"

class CacheHeadersTest < ActionDispatch::IntegrationTest
  test "anonymous feed responses emit shared cache headers" do
    get root_path

    assert_response :success
    assert_includes response.headers["Cache-Control"].to_s, "public"
    assert_includes response.headers["Cache-Control"].to_s, "s-maxage=300"
  end

  test "anonymous post detail responses emit shared cache headers" do
    get post_path(posts(:commented_post))

    assert_response :success
    assert_includes response.headers["Cache-Control"].to_s, "public"
    assert_includes response.headers["Cache-Control"].to_s, "s-maxage=300"
  end

  test "authenticated feed responses stay uncacheable at the edge" do
    sign_in_as(users(:active_member))

    get root_path

    assert_response :success
    refute_includes response.headers["Cache-Control"].to_s, "s-maxage=300"
  end
end
