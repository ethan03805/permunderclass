require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "page_title joins page title with app title" do
    assert_equal "Home · permanentunderclass.me", page_title("Home")
  end

  test "page_title falls back to app title" do
    assert_equal "permanentunderclass.me", page_title(nil)
  end

  test "nav_link_class marks the current path as active" do
    with_request_url("/") do
      assert_equal "site-nav__link is-active", nav_link_class("/")
    end
  end

  test "nav_link_class leaves non-current paths inactive" do
    with_request_url("/") do
      assert_equal "site-nav__link", nav_link_class("/up")
    end
  end

  private

  def with_request_url(path)
    request = ActionDispatch::TestRequest.create
    request.path = path

    @controller = ApplicationController.new
    @request = request
    @controller.request = request

    yield
  ensure
    @controller = nil
    @request = nil
  end
end
