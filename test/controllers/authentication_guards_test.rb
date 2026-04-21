require "test_helper"

class VerifiedInteractionsController < ApplicationController
  before_action :require_verified_user!

  def index
    head :ok
  end
end

class ActiveInteractionsController < ApplicationController
  before_action :require_active_user!

  def index
    head :ok
  end
end

class VerifiedInteractionsControllerTest < ActionController::TestCase
  tests VerifiedInteractionsController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      root "home#index"
      get "sign-in", to: "sessions#new", as: :sign_in
      get "verified-interactions", to: "verified_interactions#index"
    end
  end

  test "anonymous requests are redirected to sign in" do
    get :index

    assert_redirected_to "/sign-in"
  end

  test "pending user is redirected away from verified interaction" do
    session[:user_id] = users(:pending_member).id

    get :index

    assert_redirected_to "/"
    assert_equal I18n.t("auth.guards.email_verification_required"), flash[:alert]
  end

  test "active verified user may continue" do
    session[:user_id] = users(:active_member).id

    get :index

    assert_response :success
  end
end

class ActiveInteractionsControllerTest < ActionController::TestCase
  tests ActiveInteractionsController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      root "home#index"
      get "sign-in", to: "sessions#new", as: :sign_in
      get "active-interactions", to: "active_interactions#index"
    end
  end

  test "suspended user is redirected away from active interaction" do
    session[:user_id] = users(:suspended_member).id

    get :index

    assert_redirected_to "/"
    assert_equal I18n.t("auth.guards.account_states.suspended"), flash[:alert]
  end

  test "anonymous user is redirected to sign in" do
    get :index

    assert_redirected_to "/sign-in"
  end

  test "pending user is redirected until email is verified" do
    session[:user_id] = users(:pending_member).id

    get :index

    assert_redirected_to "/"
    assert_equal I18n.t("auth.guards.email_verification_required"), flash[:alert]
  end

  test "banned user is redirected away from active interaction" do
    session[:user_id] = users(:banned_member).id

    get :index

    assert_redirected_to "/"
    assert_equal I18n.t("auth.guards.account_states.banned"), flash[:alert]
  end
end
