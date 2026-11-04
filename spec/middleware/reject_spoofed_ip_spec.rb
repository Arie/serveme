# typed: false
# frozen_string_literal: true

require "spec_helper"

describe RejectSpoofedIp do
  let(:inner) { ->(_env) { [ 200, {}, [ "ok" ] ] } }
  let(:app) { ActionDispatch::RemoteIp.new(described_class.new(inner), true, Rails.application.config.action_dispatch.trusted_proxies) }

  it "returns 400 for conflicting Client-Ip and X-Forwarded-For headers" do
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "172.18.0.6", "HTTP_CLIENT_IP" => "184.202.234.34", "HTTP_X_FORWARDED_FOR" => "131.76.108.2, 45.138.12.45")
    expect(app.call(env)[0]).to eq(400)
  end

  it "passes normal proxied requests through" do
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "172.18.0.6", "HTTP_X_FORWARDED_FOR" => "83.175.190.98, 172.69.194.140")
    expect(app.call(env)).to eq([ 200, {}, [ "ok" ] ])
  end

  it "is in the middleware stack right after RemoteIp" do
    stack = Rails.application.middleware.middlewares
    expect(stack.index(described_class)).to eq(stack.index(ActionDispatch::RemoteIp) + 1)
  end
end
