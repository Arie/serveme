require 'spec_helper'

describe AnnounceDonatorWorker do

  it "tells the servers someone donated" do
    server = create :server
    paypal_order = create :paypal_order

    Server.should_receive(:active).and_return [server]
    server.should_receive(:rcon_say).with("#{paypal_order.user.nickname} just donated to serveme.tf - #{paypal_order.product.name}!")

    AnnounceDonatorWorker.perform_async(paypal_order.id)
  end

end

