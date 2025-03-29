# typed: false
require 'spec_helper'

RSpec.describe RglProfile do
  let(:banned_profile_json) do
    {
      name: 'Banned Player',
      status: { isBanned: true },
      banInformation: {
        reason: 'Cheating <script>alert("xss")</script>',
        endsAt: '2025-01-01'
      }
    }.to_json
  end

  let(:clean_profile_json) do
    {
      name: 'Clean Player',
      status: { isBanned: false }
    }.to_json
  end

  describe '#initialize' do
    it 'parses the JSON profile data' do
      profile = RglProfile.new(clean_profile_json)
      expect(profile.json['name']).to eq('Clean Player')
    end
  end

  describe '#league_name' do
    it 'returns RGL' do
      profile = RglProfile.new(clean_profile_json)
      expect(profile.league_name).to eq('RGL')
    end
  end

  describe '#name' do
    it 'returns the player name' do
      profile = RglProfile.new(clean_profile_json)
      expect(profile.name).to eq('Clean Player')
    end
  end

  describe '#banned?' do
    it 'returns true for banned players' do
      profile = RglProfile.new(banned_profile_json)
      expect(profile.banned?).to be true
    end

    it 'returns false for clean players' do
      profile = RglProfile.new(clean_profile_json)
      expect(profile.banned?).to be false
    end
  end

  describe '#ban_reason' do
    it 'returns raw ban reason for banned players' do
      profile = RglProfile.new(banned_profile_json)
      expect(profile.ban_reason).to eq('Cheating <script>alert("xss")</script>')
    end

    it 'returns nil for clean players' do
      profile = RglProfile.new(clean_profile_json)
      expect(profile.ban_reason).to be_nil
    end
  end

  describe '#ban_expires_at' do
    it 'returns expiry date for banned players' do
      profile = RglProfile.new(banned_profile_json)
      expect(profile.ban_expires_at).to eq(Date.parse('2025-01-01'))
    end

    it 'returns nil for clean players' do
      profile = RglProfile.new(clean_profile_json)
      expect(profile.ban_expires_at).to be_nil
    end
  end

  describe '.fetch' do
    let(:steam_uid) { '76561198012598620' }

    context 'when API call succeeds' do
      before do
        allow(RglApi).to receive(:profile).with(steam_uid).and_return(clean_profile_json)
      end

      it 'returns an RglProfile instance' do
        profile = RglProfile.fetch(steam_uid)
        expect(profile).to be_a(RglProfile)
        expect(profile.name).to eq('Clean Player')
      end
    end

    context 'when API call fails' do
      before do
        allow(RglApi).to receive(:profile).with(steam_uid).and_return(nil)
      end

      it 'returns nil' do
        expect(RglProfile.fetch(steam_uid)).to be_nil
      end
    end
  end
end
