# typed: true

class SdrController < ApplicationController
  skip_before_action :redirect_if_country_banned, only: [ :index ]
  skip_before_action :authenticate_user!, only: [ :index ]
  before_action :authenticate_user_allow_vpn!, only: [ :index ]

  def index
    if user_signed_in? && current_user
      current_user.update(current_sign_in_ip: request.remote_ip, updated_at: Time.current)
      @on_vpn = ReservationPlayer.banned_asn_ip?(request.remote_ip)
      compute_eligibility_details if current_user.uid.present?
    end

    @result = nil
    return unless params[:ip_port].present?

    @result = SdrResolver.resolve(params[:ip_port])&.connect_string
  end

  private

  def authenticate_user_allow_vpn!
    return unless user_signed_in?

    if current_user.banned?
      ban_reason = current_user.ban_reason
      Rails.logger.info "Logging out banned player with user id #{current_user.id} steam uid #{current_user.uid}, IP #{current_user.current_sign_in_ip}, name #{current_user.name}, reason: #{ban_reason}"
      sign_out(current_user)
      flash[:alert] = "You have been banned: #{ban_reason}"
      redirect_to root_path
    end
  end

  def compute_eligibility_details
    steam_uid = current_user.uid.to_i

    @first_played_at = ReservationPlayer.joins(:reservation)
      .where(steam_uid: steam_uid)
      .minimum("reservations.starts_at")
    @longtime_player = @first_played_at.present? && @first_played_at < 1.year.ago

    @connected_with_real_ip_recently = ReservationPlayer.has_connected_with_normal_ip_recently?(steam_uid)
    @logged_in_with_real_ip_recently = ReservationPlayer.has_logged_in_with_normal_ip_recently?(steam_uid)

    @sdr_eligible = @longtime_player || @connected_with_real_ip_recently || @logged_in_with_real_ip_recently
  end
end
