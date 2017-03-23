# frozen_string_literal: true
class SessionsController < Devise::OmniauthCallbacksController

  skip_before_action :verify_authenticity_token

  include Devise::Controllers::Rememberable#

  def steam
    user = User.find_for_steam_auth(request.env['omniauth.auth'])

    if user
      remember_me(user)
      sign_in_and_redirect(user, :event => :authentication)
      set_flash_message(:notice, :success, :kind => "Steam") if is_navigational_format?
    end
  end

  def failure
  end

  def passthru
    render :template => 'pages/not_found', :status => 404
  end

end
