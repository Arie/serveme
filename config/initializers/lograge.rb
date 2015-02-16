module LogrageControllerOverride
  def append_info_to_payload(payload)
    super
    payload[:host] = request.host
    payload[:fwd] = request.remote_ip
    payload[:user_id] = current_user.try(:id)
  end
end

# should probably do this only if Rails.env is production
if Rails.env.production?
  ActionController::Base.send :prepend, LogrageControllerOverride
end
