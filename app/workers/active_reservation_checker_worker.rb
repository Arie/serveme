# frozen_string_literal: true

class ActiveReservationCheckerWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1

  def perform(reservation_id)
    @reservation = Reservation.find(reservation_id)
    @server = @reservation.server

    return unless @server

    fetch_server_stats

    if @reservation.server.occupied?
      handle_occupied_server
    else
      handle_empty_server
    end
  end

  private

  def fetch_server_stats
    Rails.cache.delete "server_info_#{@reservation.server_id}"
    @server_info = @server.server_info

    begin
      @server_info.status
      @server_info.fetch_stats
      @server_info.fetch_rcon_status
      @reservation.save_sdr_info(@server_info) if sdr_info_missing?
      ServerMetric.new(@server_info)
      @server.rcon_exec "sv_logsecret #{@reservation.logsecret}"
    rescue SteamCondenser::Error, Errno::ECONNREFUSED
      Rails.logger.warn "Couldn't update #{@reservation.server.name}"
    end
  end

  def handle_occupied_server
    @reservation.update_column(:last_number_of_players, @server_info.number_of_players)
    @reservation.update_column(:inactive_minute_counter, 0)
    @reservation.warn_nearly_over if @reservation.nearly_over?
    @reservation.apply_api_keys if @reservation.enable_demos_tf?
  end

  def handle_empty_server
    previous_number_of_players = @reservation.last_number_of_players.to_i
    @reservation.update_column(:last_number_of_players, 0)
    @reservation.increment!(:inactive_minute_counter)
    if @reservation.inactive_too_long? && !@reservation.lobby?
      @reservation.user.increment!(:expired_reservations)
      @reservation.update_attribute(:end_instantly, true)
      @reservation.end_reservation
    elsif previous_number_of_players.positive? && (@reservation.starts_at < 30.minutes.ago) && @reservation.auto_end?
      Rails.logger.warn "Automatically ending #{@reservation} because it went from occupied to empty"
      @reservation.end_reservation
    end
  end

  def sdr_info_missing?
    @server.sdr? && @reservation.sdr_ip.nil?
  end
end
