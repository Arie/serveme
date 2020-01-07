# frozen_string_literal: true

class Api::ApplicationController < ActionController::Base
  respond_to :json
  rescue_from ActiveRecord::RecordNotFound,       with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_unprocessable_entity

  before_action :verify_api_key
  before_action :set_default_response_format

  def verify_api_key
    api_user
  end

  def api_user
    @api_user ||= authenticate_params || authenticate_token || unauthorized
  end

  def uid_user
    @uid_user ||= User.find_by_uid(params[:steam_uid])
  end

  def current_user
    @current_user ||= (api_user&.admin? && uid_user) || api_user
  end

  def handle_not_found
    head :not_found
  end

  def handle_unprocessable_entity
    Rails.logger.warn "UNPROCESSABLE ENTITY: #{request.body.read}"
    head :unprocessable_entity
  end

  private

  def authenticate_params
    User.find_by(api_key: params[:api_key]) if params[:api_key]
  end

  def authenticate_token
    authenticate_with_http_token do |token, _options|
      User.find_by(api_key: token)
    end
  end

  def unauthorized
    head :unauthorized
    nil
  end

  def set_default_response_format
    request.format = :json
  end
end
