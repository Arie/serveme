# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StacDiscordNotifier do
  let(:reservation) { create(:reservation) }
  let(:notifier) { described_class.new(reservation) }
  let(:detections) do
    {
      76561199543859315 => {
        name: 'АБАРИГЕН',
        steam_id64: 76561199543859315,
        detections: [ 'SilentAim' ] * 37 + [ 'OOB cvar/netvar value -1 on var cl_cmdrate' ] * 4
      },
      76561198123456789 => {
        name: 'Player2',
        steam_id64: 76561198123456789,
        detections: [ 'SilentAim' ] * 2  # Should be filtered out
      },
      76561198987654321 => {
        name: 'Player3',
        steam_id64: 76561198987654321,
        detections: [ 'Triggerbot' ] * 3  # Should be included
      },
      76561198111111111 => {
        name: 'Player4',
        steam_id64: 76561198111111111,
        detections: [ 'CmdNum SPIKE' ] * 2  # Should be filtered out
      },
      76561198222222222 => {
        name: 'Player5',
        steam_id64: 76561198222222222,
        detections: [ 'Aimsnap' ] * 3  # Should be included
      }
    }
  end

  describe '#notify' do
    it 'sends a properly formatted Discord notification with filtered detections' do
      http_double = instance_double(Net::HTTP)
      expect(Net::HTTP).to receive(:new).with(anything, anything).and_return(http_double)
      expect(http_double).to receive(:use_ssl=).with(true)

      expect(http_double).to receive(:request) do |request|
        payload = JSON.parse(request.body)
        embed = payload['embeds'].first

        # Check basic structure
        expect(embed['title']).to eq('StAC Detection Report')
        expect(embed['color']).to eq(0xFF0000)

        # Check description
        description = embed['description']
        expect(description).to include(reservation.server.name)
        expect(description).to include("#{SITE_URL}/reservations/#{reservation.id}")
        expect(description).to include("#{SITE_URL}/reservations/#{reservation.id}/stac_log")

        # Check player fields - should only include players with enough detections
        fields = embed['fields']
        expect(fields.length).to eq(3)  # Only 3 players should remain after filtering

        # Check АБАРИГЕН's detections (should be included)
        abarigin = fields.find { |f| f['name'] == 'АБАРИГЕН' }
        expect(abarigin['value']).to include('SteamID: [76561199543859315]')
        expect(abarigin['value']).to include('SilentAim: 37x')
        expect(abarigin['value']).to include('OOB cvar/netvar value -1 on var cl_cmdrate: 4x')

        # Check Player3's detections (should be included)
        player3 = fields.find { |f| f['name'] == 'Player3' }
        expect(player3['value']).to include('SteamID: [76561198987654321]')
        expect(player3['value']).to include('Triggerbot: 3x')

        # Check Player5's detections (should be included)
        player5 = fields.find { |f| f['name'] == 'Player5' }
        expect(player5['value']).to include('SteamID: [76561198222222222]')
        expect(player5['value']).to include('Aimsnap: 3x')

        # Ensure filtered players are not included
        expect(fields.none? { |f| f['name'] == 'Player2' }).to be true
        expect(fields.none? { |f| f['name'] == 'Player4' }).to be true
      end

      notifier.notify(detections)
    end

    it 'returns early if detections are empty' do
      expect(Net::HTTP).not_to receive(:new)
      notifier.notify({})
    end

    it 'returns early if all detections are filtered out' do
      filtered_detections = {
        76561198123456789 => {
          name: 'Player2',
          steam_id64: 76561198123456789,
          detections: [ 'SilentAim' ] * 2  # Below threshold
        }
      }
      expect(Net::HTTP).not_to receive(:new)
      notifier.notify(filtered_detections)
    end
  end
end
