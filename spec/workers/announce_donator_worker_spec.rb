# frozen_string_literal: true
require 'spec_helper'

describe AnnounceDonatorWorker do
  it 'tells the servers someone donated' do
    server = create :server
    nickname = 'foo'
    product_name = '1 year'

    expect(Server).to receive(:active).and_return [server]
    expect(server).to receive(:rcon_say).with("#{nickname} just donated to serveme.tf - #{product_name}! 0 percent of our monthly server bills are now taken care of")

    AnnounceDonatorWorker.perform_async(nickname, product_name)
  end
end
