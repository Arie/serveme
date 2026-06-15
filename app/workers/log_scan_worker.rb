# typed: true
# frozen_string_literal: true

class LogScanWorker
  include Sidekiq::Worker
  extend T::Sig

  sidekiq_options retry: false

  attr_accessor :reservation_id

  sig { params(reservation_id: Integer).void }
  def perform(reservation_id)
    @reservation_id = reservation_id
    scan_logs
    link_found_players_to_reservation
  end

  sig { returns(T::Array[T.untyped]) }
  def players
    @players ||= []
  end

  sig { returns(T::Array[T.untyped]) }
  def logs_tf_uploads
    @logs_tf_uploads ||= []
  end

  sig { returns(T::Array[T.untyped]) }
  def scan_logs
    logs.collect do |l|
      players << FindPlayersInLog.perform(l)
    end
  end

  sig { void }
  def link_found_players_to_reservation
    players.reject(&:empty?).flatten.uniq.each do |steam_uid|
      ReservationPlayer.where(reservation_id: reservation_id, steam_uid: steam_uid).first_or_create!
    end
  end

  sig { returns(T::Array[String]) }
  def logs
    log_pattern = Rails.root.join("server_logs", reservation_id.to_s, "*.log")
    Dir.glob(log_pattern.to_s)
  end
end
