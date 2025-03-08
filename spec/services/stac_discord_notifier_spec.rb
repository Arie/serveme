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
        detections: ['SilentAim'] * 37 + ['OOB cvar/netvar value -1 on var cl_cmdrate'] * 4
      }
    }
  end
  let(:demo_info) do
    {
      filename: 'auto-20250307-1048-ctf_2fort.dem',
      tick: '144641'
    }
  end
  let(:demo_timeline) do
    {
      'auto-20250307-1048-ctf_2fort.dem' => [8411, 10747, 19994, 78659, 78983, 80660, 82420, 88258, 97681, 124684, 144641]
    }
  end

  describe '#notify' do
    it 'sends a properly formatted Discord notification' do
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
        expect(description).to include(demo_info[:filename])
        expect(description).to include("Latest tick: #{demo_info[:tick]}")
        expect(description).to include(demo_timeline.first[0])
        expect(description).to include(demo_timeline.first[1].join(', '))

        # Check player fields
        field = embed['fields'].first
        expect(field['name']).to eq('АБАРИГЕН')
        expect(field['value']).to include('SilentAim: 37x')
        expect(field['value']).to include('OOB cvar/netvar value -1 on var cl_cmdrate: 4x')
      end

      notifier.notify(detections, demo_info, demo_timeline)
    end

    it 'returns early if detections are empty' do
      expect(Net::HTTP).not_to receive(:new)
      notifier.notify({}, demo_info, demo_timeline)
    end
  end
end
