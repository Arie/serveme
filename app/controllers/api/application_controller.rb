# frozen_string_literal: true
class Api::ApplicationController < ActionController::Base

  respond_to :json
  rescue_from ActiveRecord::RecordNotFound,       :with => :handle_not_found
  rescue_from ActionController::ParameterMissing, :with => :handle_unprocessable_entity

  before_filter :verify_api_key

  def verify_api_key
    current_user
  end

  def api_user
    begin
      @api_key_user ||= User.find_by_api_key!(params[:api_key])
    rescue ActiveRecord::RecordNotFound
      head :unauthorized
    end
  end

  def uid_user
    @uid_user ||= User.find_by_uid(params[:steam_uid])
  end

  def current_user
    @current_user ||= begin
                        if api_user && uid_user
                          uid_user
                        else
                          api_user
                        end
                      end
  end

  def handle_not_found
    head :not_found
  end

  def handle_unprocessable_entity
    Rails.logger.warn "UNPROCESSABLE ENTITY: #{request.body.read}"
    head :unprocessable_entity
  end

end
