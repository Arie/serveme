class ApplicationController < ActionController::Base

  include ApplicationHelper

  protect_from_forgery
  before_filter :authenticate_user!
end
