# typed: false

require 'spec_helper'

describe ReservationPlayer do
  context 'banned asns' do
    it 'doesnt flag good ASNs' do
      good_ip = '1.128.0.1'
      expect(described_class.banned_asn_ip?(good_ip)).to be false
    end

    it 'recognizes bad ASNs' do
      described_class.stub(:custom_banned_asns).and_return([ 1221 ])
      expect(described_class.banned_asn_ip?('1.128.0.1')).to be true
    end

    it 'knows custom range of VPN IPs not from a specific ASN' do
      described_class.stub(:vpn_ranges).and_return([ IPAddr.new('1.129.0.0/24') ])
      expect(described_class.banned_asn_ip?('1.129.0.1')).to be true
    end

    it 'knows SDR ips wont be in the ASN database, so should just return false for those' do
      expect(described_class.banned_asn_ip?('169.254.1.1')).to be false
    end
  end

  context 'banned steam ids' do
    it 'recognizes a banned steam id' do
      expect(described_class.banned_uid?(76561198310925535)).to eql 'match invader'
    end
    it 'doesnt flag a good steam id as banned' do
      expect(described_class.banned_uid?(76561197960497430)).to be_falsy
    end
  end

  context 'whitelisted steam id' do
    it 'recognizes a whitelisted steam id' do
      expect(described_class.whitelisted_uid?(76561198350261670)).to eql 'formerly lived in Russia'
    end

    it 'doesnt flag an unknown steam id as whitelisted' do
      expect(described_class.whitelisted_uid?('foobarwidget')).to be_falsy
    end
  end

  context 'banned ip' do
    it 'recognizes a banned ip in a range' do
      expect(described_class.banned_ip?('109.81.174.1')).to be_truthy
    end
    it 'doesnt flag a good ip as banned' do
      expect(described_class.banned_ip?('127.0.0.1')).to be_falsy
    end
  end

  context 'SDR IP detection' do
    it 'recognizes SDR IPs' do
      expect(described_class.sdr_ip?('169.254.1.1')).to be true
      expect(described_class.sdr_ip?('169.254.255.255')).to be true
    end

    it 'does not flag normal IPs as SDR' do
      expect(described_class.sdr_ip?('1.128.0.1')).to be false
      expect(described_class.sdr_ip?('192.168.1.1')).to be false
    end
  end

  context 'normal IP connection history' do
    let(:steam_uid) { 76561198000000001 }
    let(:reservation) { create(:reservation) }
    let(:other_reservation) { create(:reservation) }

    it 'checks if player has connected with valid normal IP per reservation' do
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be false

      # Other reservation
      create(:reservation_player, steam_uid: steam_uid, ip: '1.128.0.1', reservation: other_reservation)
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be false

      # SDR IP
      create(:reservation_player, steam_uid: steam_uid, ip: '169.254.1.1', reservation: reservation)
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be false

      # Banned IP (from banned_ips.csv)
      create(:reservation_player, steam_uid: steam_uid, ip: '79.118.14.197', reservation: reservation)
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be false

      # Banned ASN (mocked since test MaxMind DB is limited)
      allow(described_class).to receive(:banned_asn_ip?).and_call_original
      allow(described_class).to receive(:banned_asn_ip?).with('5.5.5.5').and_return(true)
      create(:reservation_player, steam_uid: steam_uid, ip: '5.5.5.5', reservation: reservation)
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be false

      # Valid IP allows SDR
      create(:reservation_player, steam_uid: steam_uid, ip: '1.128.0.1', reservation: reservation)
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be true
    end
  end

  context 'longtime serveme player' do
    let(:steam_uid) { 76561198000000001 }

    it 'returns true when player first connected over a year ago' do
      old_reservation = create(:reservation)
      old_reservation.update_column(:starts_at, 13.months.ago)
      create(:reservation_player, steam_uid: steam_uid, reservation: old_reservation)
      expect(described_class.longtime_serveme_player?(steam_uid)).to be true
    end

    it 'returns false when player first connected less than a year ago' do
      recent_reservation = create(:reservation)
      recent_reservation.update_column(:starts_at, 6.months.ago)
      create(:reservation_player, steam_uid: steam_uid, reservation: recent_reservation)
      expect(described_class.longtime_serveme_player?(steam_uid)).to be false
    end

    it 'returns false when player has never connected' do
      expect(described_class.longtime_serveme_player?(steam_uid)).to be false
    end

    it 'uses oldest reservation date when player has multiple reservations' do
      old_reservation = create(:reservation)
      old_reservation.update_column(:starts_at, 13.months.ago)
      mid_reservation = create(:reservation)
      mid_reservation.update_column(:starts_at, 6.months.ago)
      recent_reservation = create(:reservation)
      recent_reservation.update_column(:starts_at, 1.month.ago)

      create(:reservation_player, steam_uid: steam_uid, reservation: mid_reservation)
      create(:reservation_player, steam_uid: steam_uid, reservation: old_reservation)
      create(:reservation_player, steam_uid: steam_uid, reservation: recent_reservation)

      expect(described_class.longtime_serveme_player?(steam_uid)).to be true
    end
  end

  context 'SDR eligible Steam profile' do
    let(:steam_uid) { 76561198000000001 }
    let(:steam_profile) { instance_double(SteamCondenser::Community::SteamId) }

    before do
      allow(SteamCondenser::Community::SteamId).to receive(:new).with(steam_uid).and_return(steam_profile)
      # Stub longtime_serveme_player to return false by default, except in the specific test
      allow(described_class).to receive(:longtime_serveme_player?).with(steam_uid).and_return(false)
    end

    it 'returns true for longtime serveme players regardless of Steam profile' do
      old_reservation = create(:reservation)
      old_reservation.update_column(:starts_at, 13.months.ago)
      create(:reservation_player, steam_uid: steam_uid, reservation: old_reservation)
      # Override the stub to call the real method
      allow(described_class).to receive(:longtime_serveme_player?).and_call_original
      # Should not even check Steam API
      expect(SteamCondenser::Community::SteamId).not_to receive(:new)
      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be true
    end

    it 'returns true for public profile 6+ months old' do
      allow(steam_profile).to receive(:fetch)
      allow(steam_profile).to receive(:public?).and_return(true)
      allow(steam_profile).to receive(:member_since).and_return(7.months.ago)

      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be true
    end

    it 'returns false for private profile' do
      allow(steam_profile).to receive(:fetch)
      allow(steam_profile).to receive(:public?).and_return(false)

      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be false
    end

    it 'returns false for account less than 6 months old' do
      allow(steam_profile).to receive(:fetch)
      allow(steam_profile).to receive(:public?).and_return(true)
      allow(steam_profile).to receive(:member_since).and_return(3.months.ago)

      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be false
    end

    it 'returns false when member_since is nil' do
      allow(steam_profile).to receive(:fetch)
      allow(steam_profile).to receive(:public?).and_return(true)
      allow(steam_profile).to receive(:member_since).and_return(nil)

      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be false
    end

    it 'returns false when Steam API fails' do
      allow(steam_profile).to receive(:fetch).and_raise(SteamCondenser::Error)

      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be false
    end
  end
end
