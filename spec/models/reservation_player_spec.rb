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
      expect(described_class.banned_ip?('83.137.6.1')).to be_truthy
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
      create(:reservation_player, steam_uid: steam_uid, ip: '46.138.79.27', reservation: reservation)
      expect(described_class.has_connected_with_normal_ip?(steam_uid, reservation.id)).to be false

      # Banned ASN (mocked since test MaxMind test DB is limited)
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

  context 'recent real IP activity' do
    let(:steam_uid) { 76561198000000001 }

    it 'checks game server connections' do
      recent_reservation = create(:reservation)
      recent_reservation.update_column(:starts_at, 3.days.ago)
      old_reservation = create(:reservation)
      old_reservation.update_column(:starts_at, 2.weeks.ago)

      expect(described_class.has_connected_with_normal_ip_recently?(steam_uid)).to be false

      create(:reservation_player, steam_uid: steam_uid, ip: '169.254.1.1', reservation: recent_reservation)
      expect(described_class.has_connected_with_normal_ip_recently?(steam_uid)).to be false

      create(:reservation_player, steam_uid: steam_uid, ip: '1.128.0.1', reservation: old_reservation)
      expect(described_class.has_connected_with_normal_ip_recently?(steam_uid)).to be false

      create(:reservation_player, steam_uid: steam_uid, ip: '1.128.0.1', reservation: recent_reservation)
      expect(described_class.has_connected_with_normal_ip_recently?(steam_uid)).to be true
    end

    it 'checks website activity' do
      expect(described_class.has_logged_in_with_normal_ip_recently?(steam_uid)).to be false

      user = create(:user, uid: steam_uid.to_s, current_sign_in_ip: '1.128.0.1', updated_at: 2.weeks.ago)
      expect(described_class.has_logged_in_with_normal_ip_recently?(steam_uid)).to be false

      user.update_columns(updated_at: 3.days.ago)
      expect(described_class.has_logged_in_with_normal_ip_recently?(steam_uid)).to be true

      user.update_columns(current_sign_in_ip: '46.138.79.27')
      expect(described_class.has_logged_in_with_normal_ip_recently?(steam_uid)).to be false
    end
  end

  context 'SDR eligibility' do
    let(:steam_uid) { 76561198000000001 }

    it 'allows longtime players' do
      old_reservation = create(:reservation)
      old_reservation.update_column(:starts_at, 13.months.ago)
      create(:reservation_player, steam_uid: steam_uid, reservation: old_reservation)
      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be true
    end

    it 'allows recent game server connections' do
      recent_reservation = create(:reservation)
      recent_reservation.update_column(:starts_at, 3.days.ago)
      create(:reservation_player, steam_uid: steam_uid, ip: '1.128.0.1', reservation: recent_reservation)
      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be true
    end

    it 'allows recent website activity' do
      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be false

      user = create(:user, uid: steam_uid.to_s, current_sign_in_ip: '1.128.0.1', updated_at: 3.days.ago)
      expect(described_class.sdr_eligible_steam_profile?(steam_uid)).to be true
    end
  end
end
