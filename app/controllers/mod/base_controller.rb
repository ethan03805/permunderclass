module Mod
  class BaseController < ApplicationController
    before_action :require_moderator!
  end
end
