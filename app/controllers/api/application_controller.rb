class Api::ApplicationController < ActionController::Base

  respond_to :json
  rescue_from ActiveRecord::RecordNotFound,       :with => :handle_not_found
  rescue_from ActionController::ParameterMissing, :with => :handle_unprocessable_entity

  before_filter :verify_api_key

  def verify_api_key
    current_user
  end

  def current_user
    begin
      @current_user ||= User.find_by_api_key!(params[:api_key])
    rescue ActiveRecord::RecordNotFound
      head :unauthorized
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
