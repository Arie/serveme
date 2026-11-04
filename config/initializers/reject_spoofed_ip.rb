# typed: true
# frozen_string_literal: true

# Conflicting Client-Ip/X-Forwarded-For headers make every later remote_ip call raise,
# including in the exceptions app, so answer 400 before anything else runs.
class RejectSpoofedIp
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      env["action_dispatch.remote_ip"].to_s
    rescue ActionDispatch::RemoteIp::IpSpoofAttackError
      return [ 400, { "content-type" => "text/plain" }, [ "Bad Request" ] ]
    end

    @app.call(env)
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::RemoteIp, RejectSpoofedIp
