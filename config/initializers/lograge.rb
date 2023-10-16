# frozen_string_literal: true

module LogrageControllerOverride
  def append_info_to_payload(payload)
    super
    payload[:ip] = request.remote_ip
    payload[:user_id] = current_user.try(:id)
  end
end

# should probably do this only if Rails.env is production
ActionController::Base.prepend LogrageControllerOverride if Rails.env.production?
