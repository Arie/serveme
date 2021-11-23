# frozen_string_literal: true

module ApplicationHelper
  def donator?
    @donator ||= current_user&.donator?
  end

  def admin?
    @admin ||= current_user&.admin?
  end

  def used_free_server_count
    Reservation.current.where(server_id: Server.without_group).count
  end

  def used_donator_server_count
    Reservation.current.where(server_id: Server.for_donators).count
  end

  def eu_system?
    SITE_URL == ('https://serveme.tf' || 'https://www.serveme.tf')
  end

  %w[au na sa sea].each do |subdomain|
    define_method("#{subdomain}_system?") { SITE_URL == "https://#{subdomain}.serveme.tf" }
  end

  def logs_tf_url(user)
    "http://logs.tf/profile/#{user.uid}"
  end

  def demos_tf_url(user)
    if user
      "https://demos.tf/profiles/#{user.uid}"
    else
      'https://demos.tf'
    end
  end

  def sdr_hidden?(reservation)
    reservation&.server&.sdr? && !(reservation.sdr_ip && reservation.sdr_port)
  end
end
