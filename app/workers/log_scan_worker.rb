# frozen_string_literal: true
class LogScanWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  attr_accessor :reservation_id, :players

  def perform(reservation_id)
    @reservation_id = reservation_id
    scan_logs
    link_found_players_to_reservation
  end

  def players
    @players ||= []
  end

  def scan_logs
    logs.collect do |l|
      players << FindPlayersInLog.perform(l)
    end
  end

  def link_found_players_to_reservation
    players.reject(&:empty?).flatten.uniq.each do |steam_uid|
      ReservationPlayer.where(reservation_id: reservation_id, steam_uid: steam_uid).first_or_create!
    end
  end

  def logs
    log_pattern = Rails.root.join("server_logs", "#{reservation_id}", "*.log")
    Dir.glob(log_pattern)
  end

end
