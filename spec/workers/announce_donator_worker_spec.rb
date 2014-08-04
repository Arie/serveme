require 'spec_helper'

describe AnnounceDonatorWorker do

  it "tells the servers someone donated" do
    server = create :server
    paypal_order = create :paypal_order

    expect(Server).to receive(:active).and_return [server]
    expect(server).to receive(:rcon_say).with("#{paypal_order.user.nickname} just donated to serveme.tf - #{paypal_order.product.name}!")

    AnnounceDonatorWorker.perform_async(paypal_order.id)
  end

end

