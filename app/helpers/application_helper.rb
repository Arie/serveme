# typed: false
# frozen_string_literal: true

module ApplicationHelper
  def donator?
    @donator ||= current_user&.donator?
  end

  def admin?
    @admin ||= current_user&.admin?
  end

  def used_free_server_count
    Reservation.current.where(server_id: Server.without_group).count + docker_hosts_used_count
  end

  def used_donator_server_count
    @used_donator_server_count ||= Reservation.current.where(server_id: Server.for_donators).count
  end

  def total_donator_server_count
    @total_donator_server_count ||= Server.for_donators.active.not_cloud.count
  end

  def free_user_reservations_in_use
    @free_user_reservations_in_use ||= SiteSetting.free_user_reservation_count(Time.current, Time.current)
  end

  def donator_user_reservations_in_use
    @donator_user_reservations_in_use ||= Reservation.current.count - free_user_reservations_in_use
  end

  def total_premium_server_count
    @total_premium_server_count ||= total_donator_server_count + docker_hosts_total_slots - (SiteSetting.free_server_limit || 0)
  end

  def free_donator_server_count
    @free_donator_server_count ||= total_donator_server_count - used_donator_server_count
  end

  def docker_hosts_total_slots
    @docker_hosts_total_slots ||= DockerHost.active.sum(:max_containers)
  end

  def docker_hosts_used_count
    @docker_hosts_used_count ||= begin
      counts = DockerHost.container_counts_during(Time.current, Time.current)
      DockerHost.active.sum { |dh| counts.fetch(dh.id.to_s, 0) }
    end
  end

  def docker_hosts_available_during(starts_at, ends_at)
    counts = DockerHost.container_counts_during(starts_at, ends_at)
    DockerHost.active.sum { |dh| [ dh.max_containers - counts.fetch(dh.id.to_s, 0), 0 ].max }
  end

  def eu_system?
    ("https://serveme.tf" || "https://www.serveme.tf") == SITE_URL
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
      "https://demos.tf"
    end
  end

  def preliminary_sdr?(reservation)
    !(reservation.sdr_ip && reservation.sdr_port)
  end

  def reservation_status_spinner_class(reservation)
    case reservation.status
    when "Ended"
      "fa-flag-checkered"
    when "Ready"
      "fa-check"
    when "SDR Ready"
      "fa-lock"
    when "Server updating, please be patient"
      "fa-gear fa-spin"
    when "Waiting to start"
      "fa-clock-o"
    when "Provisioning cloud server"
      "fa-cloud fa-spin"
    else
      "fa-spinner fa-spin"
    end
  end

  def show_server_monitoring_link?
    return true if current_user&.admin?
    return false unless current_user

    current_user.reservations.current.exists?
  end

  def status_badge_class(status)
    case status
    when "succeeded"      then "bg-success"
    when "failed"         then "bg-danger"
    when "running"        then "bg-primary"
    when "queued"         then "bg-secondary"
    when "skipped_locked" then "bg-warning text-dark"
    else "bg-secondary"
    end
  end

  def format_currency(amount, currency_code)
    I18n.with_locale(locale_for_currency(currency_code)) do
      number_to_currency(amount)
    end
  end

  def locale_for_currency(currency_code)
    case currency_code.to_s.upcase
    when "USD" then :"en-US"
    when "AUD" then :"en-AU"
    when "SGD" then :"en-SG"
    else :en
    end
  end
end
