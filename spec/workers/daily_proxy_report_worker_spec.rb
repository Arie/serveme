# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe DailyProxyReportWorker do
  let(:worker) { described_class.new }

  define_method(:create_reservation_at) do |starts_at:, ends_at:|
    reservation = create(:reservation)
    reservation.update_columns(starts_at: starts_at, ends_at: ends_at)
    reservation
  end

  describe "#perform" do
    it "calls the notifier with proxy detection data" do
      reservation = create_reservation_at(starts_at: 2.hours.ago, ends_at: 1.hour.ago)
      create(:reservation_player, reservation: reservation, ip: "1.2.3.4", steam_uid: "76561198012345678", name: "ProxyPlayer")
      IpLookup.create!(ip: "1.2.3.4", is_proxy: true, fraud_score: 90, isp: "ShadyVPN", country_code: "US")

      notifier = instance_double(ProxyDetectionDiscordNotifier)
      expect(ProxyDetectionDiscordNotifier).to receive(:new).and_return(notifier)
      expect(notifier).to receive(:notify) do |data|
        expect(data).to have_key("76561198012345678")
        expect(data["76561198012345678"][:name]).to eq("ProxyPlayer")
        expect(data["76561198012345678"][:ips]).to have_key("1.2.3.4")
        expect(data["76561198012345678"][:ips]["1.2.3.4"][:fraud_score]).to eq(90)
        expect(data["76561198012345678"][:ips]["1.2.3.4"][:reservation_ids]).to include(reservation.id)
      end

      worker.perform
    end

    it "includes residential proxy detections" do
      reservation = create_reservation_at(starts_at: 2.hours.ago, ends_at: 1.hour.ago)
      create(:reservation_player, reservation: reservation, ip: "5.6.7.8", steam_uid: "76561198087654321", name: "ResProxy")
      IpLookup.create!(ip: "5.6.7.8", is_residential_proxy: true, fraud_score: 85, isp: "ResVPN", country_code: "DE")

      notifier = instance_double(ProxyDetectionDiscordNotifier)
      expect(ProxyDetectionDiscordNotifier).to receive(:new).and_return(notifier)
      expect(notifier).to receive(:notify) do |data|
        expect(data).to have_key("76561198087654321")
      end

      worker.perform
    end

    it "excludes false positive IpLookups" do
      reservation = create_reservation_at(starts_at: 2.hours.ago, ends_at: 1.hour.ago)
      create(:reservation_player, reservation: reservation, ip: "1.2.3.4", steam_uid: "76561198012345678")
      IpLookup.create!(ip: "1.2.3.4", is_proxy: true, fraud_score: 90, isp: "ShadyVPN", country_code: "US", false_positive: true)

      expect(ProxyDetectionDiscordNotifier).not_to receive(:new)
      worker.perform
    end

    it "does nothing when there are no proxy detections" do
      expect(ProxyDetectionDiscordNotifier).not_to receive(:new)
      worker.perform
    end

    it "excludes old reservations" do
      reservation = create_reservation_at(starts_at: 2.days.ago, ends_at: 2.days.ago + 1.hour)
      create(:reservation_player, reservation: reservation, ip: "1.2.3.4", steam_uid: "76561198012345678")
      IpLookup.create!(ip: "1.2.3.4", is_proxy: true, fraud_score: 90, isp: "ShadyVPN", country_code: "US")

      expect(ProxyDetectionDiscordNotifier).not_to receive(:new)
      worker.perform
    end
  end
end
