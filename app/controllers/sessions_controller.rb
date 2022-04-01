# frozen_string_literal: true

class SessionsController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned

  include Devise::Controllers::Rememberable

  def new; end

  def steam
    user = User.find_for_steam_auth(request.env['omniauth.auth'])

    return unless user

    remember_me(user)
    sign_in_and_redirect(user, event: :authentication)

    return unless is_navigational_format?

    set_flash_message(:notice, :success, kind: 'Steam')
  end

  def failure; end

  def passthru
    render template: 'pages/not_found', status: 404
  end
end
