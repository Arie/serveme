# typed: false
# frozen_string_literal: true

class IpProxyCheckWorker
  include Sidekiq::Worker
  sidekiq_options queue: :low, retry: false

  def perform(reservation_player_id, player_uid = nil)
    rp = ReservationPlayer.find_by(id: reservation_player_id)
    return unless rp&.ip

    return if skip_check?(rp)
    return if IpLookup.cached?(rp.ip)

    ProxyDetectionService.check(rp.ip)
  rescue ProxyDetectionService::AllProvidersExhaustedError => e
    Rails.logger.warn "[ProxyDetection] All providers exhausted for #{rp.ip}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[ProxyDetection] Unexpected error for #{rp.ip}: #{e.message}"
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
end
