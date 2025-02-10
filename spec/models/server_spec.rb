# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Server do
  describe '#save_version_info' do
    let(:server) { create(:server, update_status: 'Updating', update_started_at: Time.current) }
    let(:server_info) { double('ServerInfo') }

    before do
      allow(Server).to receive(:latest_version).and_return(100)
      allow(server_info).to receive(:version)
    end

    context 'when version is nil' do
      before { allow(server_info).to receive(:version).and_return(nil) }

      it 'returns early without updating to prevent incorrect version comparison' do
        expect(server).not_to receive(:update)
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updating') # Status remains unchanged
        expect(server.last_known_version).to be_nil
      end
    end

    context 'when version is older than latest' do
      before { allow(server_info).to receive(:version).and_return(90) }

      it 'marks server as outdated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Outdated')
        expect(server.last_known_version).to eq(90)
      end
    end

    context 'when version is equal to latest' do
      before { allow(server_info).to receive(:version).and_return(100) }

      it 'marks server as updated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updated')
        expect(server.last_known_version).to eq(100)
      end
    end

    context 'when version is newer than latest' do
      before { allow(server_info).to receive(:version).and_return(110) }

      it 'marks server as updated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updated')
        expect(server.last_known_version).to eq(110)
      end
    end
  end
end
