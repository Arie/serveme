# frozen_string_literal: true

class LogScanWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  attr_accessor :reservation_id

  def perform(reservation_id)
    @reservation_id = reservation_id
    scan_logs
    link_found_players_to_reservation
    link_found_logs_tf_uploads_to_reservation
  end

  def players
    @players ||= []
  end

  def logs_tf_uploads
    @logs_tf_uploads ||= []
  end

  def scan_logs
    logs.collect do |l|
      players << FindPlayersInLog.perform(l)
      logs_tf_uploads << FindLogsTfUploadsInLog.perform(l)
    end
  end

  def link_found_players_to_reservation
    players.reject(&:empty?).flatten.uniq.each do |steam_uid|
      ReservationPlayer.where(reservation_id: reservation_id, steam_uid: steam_uid).first_or_create!
    end
  end

  def link_found_logs_tf_uploads_to_reservation
    logs_tf_uploads.reject(&:empty?).flatten.uniq.each do |id|
      l = LogUpload.new
      l.reservation_id = reservation_id
      l.url = "http://logs.tf/#{id}"
      l.status = 'TFTrue upload'
      l.save!
    end
  end

  def logs
    log_pattern = Rails.root.join('server_logs', reservation_id.to_s, '*.log')
    Dir.glob(log_pattern)
  end
end
