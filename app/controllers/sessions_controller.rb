# typed: false
# frozen_string_literal: true

class SessionsController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned

  include Devise::Controllers::Rememberable

  def new; end

  def steam
    user = User.find_for_steam_auth(request.env["omniauth.auth"])

    return unless user

    remember_me(user)

    if user.current_sign_in_ip && ReservationPlayer.banned_asn_ip?(user.current_sign_in_ip) && !user.admin?
      sign_in(user, event: :authentication)
      set_flash_message(:notice, :success, kind: "Steam") if is_navigational_format?
      redirect_to sdr_path
    else
      sign_in_and_redirect(user, event: :authentication)
      set_flash_message(:notice, :success, kind: "Steam") if is_navigational_format?
    end
  end

  def failure; end

  def passthru
    render template: "pages/not_found", status: 404
  end
end
