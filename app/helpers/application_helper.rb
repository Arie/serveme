# typed: true
# frozen_string_literal: true

module ApplicationHelper
  extend T::Sig

  # Subscribe a beta (v2) page to the parallel ":v2" Turbo stream that
  # BetaBroadcast emits the v2 variant of each partial to. See BetaBroadcast.
  sig { params(streamables: T.untyped).returns(T.untyped) }
  def turbo_stream_from_beta(*streamables)
    T.unsafe(self).turbo_stream_from(*streamables, BetaBroadcast::VARIANT)
  end

  sig { returns(T.nilable(T::Boolean)) }
  def donator?
    @donator ||= T.unsafe(self).current_user&.donator?
  end

  sig { returns(T.nilable(T::Boolean)) }
  def admin?
    @admin ||= T.unsafe(self).current_user&.admin?
  end

  sig { returns(Integer) }
  def used_free_server_count
    Reservation.current.where(server_id: Server.without_group).count + docker_hosts_used_count
  end

  sig { returns(Integer) }
  def used_donator_server_count
    @used_donator_server_count ||= Reservation.current.where(server_id: Server.for_donators).count
  end

  sig { returns(Integer) }
  def total_donator_server_count
    @total_donator_server_count ||= Server.for_donators.active.not_cloud.count
  end

  sig { returns(Integer) }
  def free_user_reservations_in_use
    @free_user_reservations_in_use ||= SiteSetting.free_user_reservation_count(Time.current, Time.current)
  end

  sig { returns(Integer) }
  def donator_user_reservations_in_use
    @donator_user_reservations_in_use ||= Reservation.current.count - free_user_reservations_in_use
  end

  sig { returns(Integer) }
  def total_premium_server_count
    @total_premium_server_count ||= total_donator_server_count + docker_hosts_total_slots - (SiteSetting.free_server_limit || 0)
  end

  sig { returns(Integer) }
  def free_donator_server_count
    @free_donator_server_count ||= total_donator_server_count - used_donator_server_count
  end

  sig { returns(Integer) }
  def docker_hosts_total_slots
    @docker_hosts_total_slots ||= DockerHost.active.sum(:max_containers)
  end

  sig { returns(Integer) }
  def docker_hosts_used_count
    @docker_hosts_used_count ||= begin
      counts = DockerHost.container_counts_during(Time.current, Time.current)
      DockerHost.active.sum { |dh| counts.fetch(dh.id.to_s, 0) }
    end
  end

  sig { params(starts_at: T.untyped, ends_at: T.untyped).returns(Integer) }
  def docker_hosts_available_during(starts_at, ends_at)
    counts = DockerHost.container_counts_during(starts_at, ends_at)
    DockerHost.active.sum { |dh| [ T.must(dh.max_containers) - counts.fetch(dh.id.to_s, 0), 0 ].max }
  end

  sig { returns(T::Boolean) }
  def eu_system?
    # NOTE: `"a" || "b"` short-circuits to the first string, so only the EU URL ever matches.
    "https://serveme.tf" == SITE_URL
  end

  %w[au na sa sea].each do |subdomain|
    define_method("#{subdomain}_system?") { SITE_URL == "https://#{subdomain}.serveme.tf" }
  end

  sig { params(user: T.untyped).returns(String) }
  def logs_tf_url(user)
    "http://logs.tf/profile/#{user.uid}"
  end

  sig { params(user: T.untyped).returns(String) }
  def demos_tf_url(user)
    if user
      "https://demos.tf/profiles/#{user.uid}"
    else
      "https://demos.tf"
    end
  end

  sig { params(reservation: Reservation).returns(T::Boolean) }
  def preliminary_sdr?(reservation)
    !(reservation.sdr_ip && reservation.sdr_port)
  end

  sig { params(reservation: Reservation).returns(String) }
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

  sig { returns(T::Boolean) }
  def show_server_monitoring_link?
    current_user = T.unsafe(self).current_user
    return true if current_user&.admin?
    return false unless current_user

    current_user.reservations.current.exists?
  end

  sig { params(status: T.nilable(String)).returns(String) }
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

  sig { params(amount: T.untyped, currency_code: T.untyped).returns(String) }
  def format_currency(amount, currency_code)
    I18n.with_locale(locale_for_currency(currency_code)) do
      T.unsafe(self).number_to_currency(amount)
    end
  end

  sig { params(currency_code: T.untyped).returns(Symbol) }
  def locale_for_currency(currency_code)
    case currency_code.to_s.upcase
    when "USD" then :"en-US"
    when "AUD" then :"en-AU"
    when "SGD" then :"en-SG"
    else :en
    end
  end
end
