# typed: false
# frozen_string_literal: true

require "spec_helper"
require Rails.root.join("config/initializers/lograge")

describe LogrageControllerOverride do
  let(:controller_class) do
    Class.new do
      define_method(:append_info_to_payload) { |_payload| }
      attr_accessor :request, :current_user
    end.tap { |k| k.prepend(LogrageControllerOverride) }
  end

  it "writes ip, user_id, and request_id into the payload" do
    controller = controller_class.new
    controller.request = double(remote_ip: "1.2.3.4", request_id: "req-xyz")
    controller.current_user = double(id: 42)

    payload = {}
    controller.append_info_to_payload(payload)

    expect(payload).to eq(ip: "1.2.3.4", user_id: 42, request_id: "req-xyz")
  end

  it "handles a missing current_user" do
    controller = controller_class.new
    controller.request = double(remote_ip: "1.2.3.4", request_id: "req-xyz")
    controller.current_user = nil

    payload = {}
    controller.append_info_to_payload(payload)

    expect(payload).to eq(ip: "1.2.3.4", user_id: nil, request_id: "req-xyz")
  end
end
