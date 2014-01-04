module ApplicationHelper

  def donator?
    @current_user_is_donator ||= current_user && current_user.donator?
  end

  def used_free_server_count
    Reservation.current.where(:server_id => Server.without_group).count
  end

  def used_donator_server_count
    Reservation.current.where(:server_id => Server.for_donators).count
  end

  def na_system?
    SITE_URL == 'http://na.serveme.tf'
  end

  def eu_system?
    SITE_URL == 'http://serveme.tf'
  end

end
