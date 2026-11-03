# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Rack::Attack do
  before { Rails.cache.clear }

  it "bans an ip after repeated motd password failures" do
    9.times { described_class.motd_password_failed!("1.2.3.4") }
    expect(described_class.motd_banned?("1.2.3.4")).to be false

    described_class.motd_password_failed!("1.2.3.4")
    expect(described_class.motd_banned?("1.2.3.4")).to be true
    expect(described_class.motd_banned?("5.6.7.8")).to be false
  end

  it "uses the client ip behind Cloudflare" do
    inner = ->(env) { [ 200, {}, [ Rack::Attack::Request.new(env).remote_ip ] ] }
    app = ActionDispatch::RemoteIp.new(inner, true, Rails.application.config.action_dispatch.trusted_proxies)
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "172.18.0.5", "HTTP_X_FORWARDED_FOR" => "83.175.190.98, 172.69.194.140")
    expect(app.call(env)[2].first).to eq("83.175.190.98")
  end
end
