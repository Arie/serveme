# typed: false
# frozen_string_literal: true

require "spec_helper"

describe AnnouncePlayerWorker do
  let(:user) { create(:user) }
  let(:server) { create(:server) }
  let(:reservation) { create(:reservation, user: user, server: server) }
  let(:steam_uid) { 76561198012345678 }
  let(:ip) { "85.139.95.110" }

  before do
    allow_any_instance_of(Server).to receive(:rcon_say)
    allow_any_instance_of(Server).to receive(:rcon_disconnect)
    allow(Geocoder).to receive(:search).and_return([])
    allow(ReservationPlayer).to receive(:asn).and_return(nil)
  end

  describe "#perform" do
    it "announces a brand new player" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/First game/)
      subject.perform(reservation.id, steam_uid, ip)
    end

    it "skips players who have played before" do
      create(:reservation_player, reservation: reservation, steam_uid: steam_uid, ip: ip)

      expect_any_instance_of(Server).not_to receive(:rcon_say)
      subject.perform(reservation.id, steam_uid, ip)
    end

    it "includes location and ISP for new players" do
      geocode_result = double(city: "Berlin", country: "Germany", latitude: 52.52, longitude: 13.405)
      allow(Geocoder).to receive(:search).with(ip).and_return([ geocode_result ])

      asn_data = double(autonomous_system_organization: "Deutsche Telekom", autonomous_system_number: 3320, network: double(to_s: "85.139.0.0/16"))
      allow(ReservationPlayer).to receive(:asn).with(ip).and_return(asn_data)

      expect_any_instance_of(Server).to receive(:rcon_say).with(/Berlin, Germany.*Deutsche Telekom/)
      subject.perform(reservation.id, steam_uid, ip)
    end

    it "skips SDR IPs for geolocation" do
      expect_any_instance_of(Server).to receive(:rcon_say).with(/.+: SDR\. First game/)
      subject.perform(reservation.id, steam_uid, "169.254.1.1")
    end

    it "does nothing if reservation does not exist" do
      expect_any_instance_of(Server).not_to receive(:rcon_say)
      subject.perform(999999, steam_uid, ip)
    end
  end
end
