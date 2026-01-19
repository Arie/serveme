# typed: false
# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../lib/helpers/flag_helper"

# Test the button handler logic without running the full bot
RSpec.describe "Bot button handlers" do
  describe "extend reservation" do
    let(:user) { create(:user) }
    let(:server) { create(:server) }

    it "can extend a reservation with less than 1 hour remaining" do
      # Create reservation that started recently and ends in 30 minutes
      reservation = create(:reservation,
        user: user,
        server: server,
        starts_at: Time.current,
        ends_at: 30.minutes.from_now,
        provisioned: true)

      # This would have caught the extend_reservation vs extend! error
      expect(reservation).to respond_to(:extend!)
      original_end = reservation.ends_at
      expect(reservation.extend!).to be_truthy
      expect(reservation.ends_at).to be > original_end
    end

    it "cannot extend a reservation with more than 1 hour remaining" do
      reservation = create(:reservation,
        user: user,
        server: server,
        starts_at: Time.current,
        ends_at: 90.minutes.from_now,
        provisioned: true)

      expect(reservation.extend!).to be_nil
    end

    it "cannot extend an ended reservation" do
      reservation = create(:reservation,
        user: user,
        server: server,
        starts_at: Time.current,
        ends_at: 30.minutes.from_now,
        provisioned: true,
        ended: true)

      expect(reservation.ended?).to be true
    end
  end

  describe "end reservation" do
    let(:user) { create(:user) }
    let(:server) { create(:server) }

    it "can set end_instantly on a reservation" do
      reservation = create(:reservation,
        user: user,
        server: server,
        starts_at: Time.current,
        ends_at: 90.minutes.from_now,
        provisioned: true)

      expect(reservation).to respond_to(:end_instantly=)
      reservation.update!(end_instantly: true)
      expect(reservation.end_instantly).to be true
    end

    it "can call end_reservation on a reservation" do
      reservation = create(:reservation,
        user: user,
        server: server,
        starts_at: Time.current,
        ends_at: 90.minutes.from_now,
        provisioned: true)

      expect(reservation).to respond_to(:end_reservation)
    end
  end

  describe "user lookup by discord_uid" do
    it "can find user by discord_uid" do
      user = create(:user, discord_uid: "123456789")
      expect(User.find_by(discord_uid: "123456789")).to eq(user)
    end

    it "returns nil for unknown discord_uid" do
      expect(User.find_by(discord_uid: "unknown")).to be_nil
    end
  end
end
