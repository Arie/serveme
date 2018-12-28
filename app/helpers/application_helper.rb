# frozen_string_literal: true
module ApplicationHelper

  def donator?
    @current_user_is_donator ||= current_user && current_user.donator?
  end

  def admin?
    @current_user_is_admin ||= current_user && current_user.admin?
  end

  def used_free_server_count
    Reservation.current.where(:server_id => Server.without_group).count
  end

  def used_donator_server_count
    Reservation.current.where(:server_id => Server.for_donators).count
  end

  ['au', 'na', 'sa', 'sea'].each do |subdomain|
    define_method("#{subdomain}_system?") { SITE_URL == "https://#{subdomain}.serveme.tf" }
  end

end
