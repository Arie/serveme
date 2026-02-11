# typed: false
# frozen_string_literal: true

class DailyProxyReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 1

  def perform
    player_data = build_player_data
    return if player_data.empty?

    ProxyDetectionDiscordNotifier.new.notify(player_data)
  end

  private

  def build_player_data
    results = ReservationPlayer
      .joins("INNER JOIN ip_lookups ON ip_lookups.ip = reservation_players.ip")
      .joins(:reservation)
      .where("reservations.starts_at >= ?", 24.hours.ago)
      .where("(ip_lookups.is_proxy = ? OR ip_lookups.is_residential_proxy = ?)", true, true)
      .where("ip_lookups.false_positive != ?", true)
      .select(
        "reservation_players.steam_uid",
        "reservation_players.name",
        "reservation_players.ip",
        "reservation_players.reservation_id",
        "ip_lookups.fraud_score",
        "ip_lookups.isp",
        "ip_lookups.country_code"
      )

    player_data = {}

    results.each do |row|
      uid = row.steam_uid
      player_data[uid] ||= { name: row.name, ips: {} }
      player_data[uid][:ips][row.ip] ||= { fraud_score: row.fraud_score, isp: row.isp, country_code: row.country_code, reservation_ids: [] }
      player_data[uid][:ips][row.ip][:reservation_ids] << row.reservation_id unless player_data[uid][:ips][row.ip][:reservation_ids].include?(row.reservation_id)
    end

    player_data
  end
end
