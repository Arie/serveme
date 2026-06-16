# typed: false
# frozen_string_literal: true

class BetaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :redirect_if_country_banned

  def show; end

  def enable
    cookies[:ui_v2] = { value: "true", expires: 1.year, same_site: :lax }
    redirect_to root_path
  end

  def disable
    cookies.delete(:ui_v2)
    redirect_to root_path
  end
end
