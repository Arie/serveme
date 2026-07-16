# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ServerReservationEstimator do
  let(:reservation) { create(:reservation) }
  subject(:estimator) { described_class.new(reservation) }

  before { reservation.reservation_statuses.delete_all }

  describe "#provision_estimate" do
    it "is nil when there are no statuses yet" do
      expect(estimator.provision_estimate).to be_nil
    end

    it "reports completed with the fast-start phases once the reservation is ready" do
      reservation.update!(ready_at: Time.current)
      result = estimator.provision_estimate
      expect(result[:completed]).to be(true)
      expect(result[:phases]).to eq(described_class::FAST_START_PHASES)
    end

    it "maps a config status to the sending_configs phase (fast start)" do
      reservation.reservation_statuses.create!(status: "Sending reservation config files")
      result = estimator.provision_estimate
      expect(result[:phases]).to eq(described_class::FAST_START_PHASES)
      expect(result[:current_phase]).to eq("sending_configs")
    end

    it "switches to the restart phases once the server reports outdated" do
      reservation.reservation_statuses.create!(status: "Server outdated, restarting server to update")
      result = estimator.provision_estimate
      expect(result[:phases]).to eq(described_class::RESTART_PHASES)
      expect(result[:current_phase]).to eq("restarting")
    end

    it "is nil when the latest status maps to no phase" do
      reservation.reservation_statuses.create!(status: "Some unrelated status")
      expect(estimator.provision_estimate).to be_nil
    end
  end

  describe "#end_estimate" do
    it "is nil until the reservation starts ending" do
      reservation.reservation_statuses.create!(status: "Starting")
      expect(estimator.end_estimate).to be_nil
    end

    it "reports the ending phase" do
      reservation.reservation_statuses.create!(status: "Ending")
      result = estimator.end_estimate
      expect(result[:phases]).to eq(described_class::END_PHASES)
      expect(result[:current_phase]).to eq("ending")
    end

    it "is nil once zipping has finished" do
      reservation.reservation_statuses.create!(status: "Ending")
      reservation.reservation_statuses.create!(status: "Finished zipping logs and demos")
      expect(estimator.end_estimate).to be_nil
    end
  end
end
