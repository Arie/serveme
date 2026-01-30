# typed: false
# frozen_string_literal: true

class IpProxyCheckWorker
  include Sidekiq::Worker
  sidekiq_options queue: :low, retry: false

  def perform(reservation_player_id, player_uid)
    @player_uid = player_uid
    rp = ReservationPlayer.find_by(id: reservation_player_id)
    return unless rp&.ip

    return if skip_check?(rp)
    return if IpLookup.cached?(rp.ip)

    result = IpQualityScoreService.check(rp.ip)

    kick_player(rp) if result&.is_residential_proxy
  rescue IpQualityScoreService::QuotaExceededError
    Rails.logger.info "[IPQS] Monthly quota exceeded, skipping check for #{rp.ip}"
  rescue IpQualityScoreService::ApiError => e
    Rails.logger.warn "[IPQS] API error for #{rp.ip}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[IPQS] Unexpected error for #{rp.ip}: #{e.message}"
  end

  private

  def skip_check?(rp)
    return true if ReservationPlayer.sdr_ip?(rp.ip)
    return true if ReservationPlayer.banned_asn_ip?(rp.ip)
    return true if ReservationPlayer.whitelisted_uid?(rp.steam_uid.to_i)
    return true if player_has_history?(rp.steam_uid.to_i)

    false
  end

  def player_has_history?(steam_uid)
    ReservationPlayer
      .joins(:reservation)
      .where(steam_uid: steam_uid)
      .where("reservations.starts_at < ?", 1.month.ago)
      .exists?
  end

  def kick_player(rp)
    reservation = rp.reservation
    return unless reservation && !reservation.ended?

    reservation.server&.rcon_exec "kickid #{@player_uid} [#{SITE_HOST}] Residential proxy detected; addip 0 #{rp.ip}"
    Rails.logger.warn "[IPQS] Kicked residential proxy: #{rp.ip} (#{rp.steam_uid}) from reservation #{reservation.id}"
  rescue SteamCondenser::Error => e
    Rails.logger.warn "[IPQS] Failed to kick player #{rp.steam_uid}: #{e.message}"
  end
end
