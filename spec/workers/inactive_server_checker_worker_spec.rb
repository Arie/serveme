# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe InactiveServerCheckerWorker do
  let(:server) { create :server, last_sdr_ip: '1.2.3.4', last_sdr_port: 27015 }
  let(:server_info) { double(:server_info, ip: '5.6.7.8', port: 27020, fetch_rcon_status: true) }

  before do
    allow(Server).to receive(:find).with(server.id).and_return(server)
    allow(server).to receive(:server_info).and_return(server_info)
    allow(server).to receive(:save_version_info)
  end

  it 'updates SDR info when server info is available with valid port' do
    expect(server).to receive(:update_columns).with(
      last_sdr_ip: '5.6.7.8',
      last_sdr_port: 27020,
      last_sdr_tv_port: 27021
    )

    InactiveServerCheckerWorker.perform_async(server.id, 12345)
  end

  it 'handles nil port gracefully without crashing' do
    allow(server_info).to receive(:port).and_return(nil)

    expect { InactiveServerCheckerWorker.perform_async(server.id, 12345) }.not_to raise_error
    expect(server).not_to receive(:update_columns)
  end

  it 'skips update when server info has no IP' do
    allow(server_info).to receive(:ip).and_return(nil)

    expect(server).not_to receive(:update_columns)
    InactiveServerCheckerWorker.perform_async(server.id, 12345)
  end

  it 'skips update when SDR info is unchanged' do
    allow(server_info).to receive(:ip).and_return('1.2.3.4')
    allow(server_info).to receive(:port).and_return('27015')

    expect(server).not_to receive(:update_columns)
    InactiveServerCheckerWorker.perform_async(server.id, 12345)
  end

  it 'handles RCON connection errors gracefully' do
    allow(server_info).to receive(:fetch_rcon_status).and_raise(SteamCondenser::Error.new("Connection failed"))
    allow(Rails.logger).to receive(:warn)

    expect { InactiveServerCheckerWorker.perform_async(server.id, 12345) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn)
  end
end
