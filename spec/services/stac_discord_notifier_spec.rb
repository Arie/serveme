# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StacDiscordNotifier do
  include Rails.application.routes.url_helpers

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

  before do
    self.default_url_options = { host: SITE_URL }
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
        expect(description).to include("#{SITE_URL}/reservations/#{reservation.id}")
        expect(description).to include("#{SITE_URL}/reservations/#{reservation.id}/stac_log")

        # Check player fields
        field = embed['fields'].first
        expect(field['name']).to eq('АБАРИГЕН')
        expect(field['value']).to include('SteamID: [76561199543859315]')
        expect(field['value']).to include("#{SITE_URL}/league-request?steam_uid=76561199543859315&cross_reference=true")
        expect(field['value']).to include('SilentAim: 37x')
        expect(field['value']).to include('OOB cvar/netvar value -1 on var cl_cmdrate: 4x')
      end

      notifier.notify(detections)
    end

    it 'returns early if detections are empty' do
      expect(Net::HTTP).not_to receive(:new)
      notifier.notify({})
    end
  end
end
