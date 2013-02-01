class ApplicationController < ActionController::Base

  include ApplicationHelper

  protect_from_forgery
  skip_before_filter :authenticate_user!

  def current_user
    User.first
  end
end
