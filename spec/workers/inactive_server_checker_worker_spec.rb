# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe InactiveServerCheckerWorker do
  let(:server) { create :server, name: 'Test Server', ip: '127.0.0.1', port: 27015, last_sdr_ip: '1.2.3.4', last_sdr_port: 27015 }
  let(:server_info) { double(:server_info, ip: '5.6.7.8', port: 27020, fetch_rcon_status: true) }
  let(:latest_version) { 12345 }

  before do
    allow(Server).to receive(:find).with(server.id).and_return(server)
    allow(server).to receive(:server_info).and_return(server_info)
    allow(server).to receive(:save_version_info)
  end

  describe 'perform' do
    it 'processes server successfully with valid server info' do
      expect(server).to receive(:save_version_info).with(server_info)
      expect(server).to receive(:update_columns).with(
        last_sdr_ip: '5.6.7.8',
        last_sdr_port: 27020,
        last_sdr_tv_port: 27021
      )

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'calls save_version_info even when save_sdr_info is skipped' do
      allow(server_info).to receive(:ip).and_return(nil)

      expect(server).to receive(:save_version_info).with(server_info)
      expect(server).not_to receive(:update_columns)

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'handles server not found' do
      allow(Server).to receive(:find).and_raise(ActiveRecord::RecordNotFound)

      expect { InactiveServerCheckerWorker.perform_async(999, latest_version) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'fetch_sdr_info' do
    it 'handles SteamCondenser::Error and logs warning' do
      allow(server_info).to receive(:fetch_rcon_status).and_raise(SteamCondenser::Error.new("Connection failed"))
      allow(Rails.logger).to receive(:warn)

      expect(server).to receive(:save_version_info).with(nil)
      expect(server).not_to receive(:update_columns)
      expect { InactiveServerCheckerWorker.perform_async(server.id, latest_version) }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with("Couldn't get RCON status of Test Server - 127.0.0.1:27015")
    end

    it 'handles Errno::ECONNREFUSED and logs warning' do
      allow(server_info).to receive(:fetch_rcon_status).and_raise(Errno::ECONNREFUSED)
      allow(Rails.logger).to receive(:warn)

      expect(server).to receive(:save_version_info).with(nil)
      expect(server).not_to receive(:update_columns)
      expect { InactiveServerCheckerWorker.perform_async(server.id, latest_version) }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with("Couldn't get RCON status of Test Server - 127.0.0.1:27015")
    end

    it 'returns server_info when fetch_rcon_status succeeds' do
      expect(server_info).to receive(:fetch_rcon_status)
      expect(server).to receive(:save_version_info).with(server_info)

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end
  end

  describe 'save_sdr_info' do
    it 'handles nil port gracefully without crashing' do
      allow(server_info).to receive(:port).and_return(nil)

      expect { InactiveServerCheckerWorker.perform_async(server.id, latest_version) }.not_to raise_error
      expect(server).not_to receive(:update_columns)
    end

    it 'skips update when server info has no IP' do
      allow(server_info).to receive(:ip).and_return(nil)

      expect(server).not_to receive(:update_columns)
      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'skips update when server info has empty IP' do
      allow(server_info).to receive(:ip).and_return('')

      expect(server).not_to receive(:update_columns)
      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'skips update when server info has empty port' do
      allow(server_info).to receive(:port).and_return('')

      expect(server).not_to receive(:update_columns)
      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'skips update when SDR info is unchanged (string port)' do
      allow(server_info).to receive(:ip).and_return('1.2.3.4')
      allow(server_info).to receive(:port).and_return('27015')

      expect(server).not_to receive(:update_columns)
      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'updates when SDR info changes (integer port vs string port)' do
      allow(server_info).to receive(:ip).and_return('1.2.3.4')
      allow(server_info).to receive(:port).and_return(27015)

      expect(server).to receive(:update_columns).with(
        last_sdr_ip: '1.2.3.4',
        last_sdr_port: 27015,
        last_sdr_tv_port: 27016
      )

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'updates when IP is different' do
      allow(server_info).to receive(:ip).and_return('9.8.7.6')
      allow(server_info).to receive(:port).and_return(27015)

      expect(server).to receive(:update_columns).with(
        last_sdr_ip: '9.8.7.6',
        last_sdr_port: 27015,
        last_sdr_tv_port: 27016
      )

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'updates when port is different' do
      allow(server_info).to receive(:ip).and_return('1.2.3.4')
      allow(server_info).to receive(:port).and_return(27020)

      expect(server).to receive(:update_columns).with(
        last_sdr_ip: '1.2.3.4',
        last_sdr_port: 27020,
        last_sdr_tv_port: 27021
      )

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end

    it 'calculates TV port correctly for various port numbers' do
      allow(server_info).to receive(:ip).and_return('5.6.7.8')
      allow(server_info).to receive(:port).and_return(9999)

      expect(server).to receive(:update_columns).with(
        last_sdr_ip: '5.6.7.8',
        last_sdr_port: 9999,
        last_sdr_tv_port: 10000
      )

      InactiveServerCheckerWorker.perform_async(server.id, latest_version)
    end
  end
end
