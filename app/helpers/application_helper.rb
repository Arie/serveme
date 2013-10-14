module ApplicationHelper

  def donator?
    @current_user_is_donator ||= current_user && current_user.donator?
  end

end
