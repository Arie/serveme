# typed: false
# frozen_string_literal: true

require "spec_helper"

describe ReservationsHelper do
  describe "#free_docker_hosts" do
    let(:reservation) { Reservation.new(starts_at: Time.current, ends_at: 2.hours.from_now) }

    before do
      allow(helper).to receive(:free_server_limit_reached_for_reservation?).and_return(false)
      helper.instance_variable_set(:@reservation, reservation)
    end

    it "returns active docker hosts when the image is current" do
      docker_host = create(:docker_host)
      allow(DockerImageReadiness).to receive(:stale?).and_return(false)

      expect(helper.free_docker_hosts).to include(docker_host)
    end

    it "returns no docker hosts when the image is stale" do
      create(:docker_host)
      allow(DockerImageReadiness).to receive(:stale?).and_return(true)

      expect(helper.free_docker_hosts).to eq([])
    end
  end

  describe "#starts_at" do
    it "parses a future starts_at string from params" do
      future = 1.hour.from_now
      allow(helper).to receive(:params).and_return(
        ActionController::Parameters.new(starts_at: future.iso8601)
      )

      expect(helper.send(:starts_at)).to be_within(1.second).of(future)
    end

    it "returns Time.current when starts_at string is in the past" do
      allow(helper).to receive(:params).and_return(
        ActionController::Parameters.new(starts_at: 1.hour.ago.iso8601)
      )

      expect(helper.send(:starts_at)).to be_within(1.second).of(Time.current)
    end

    it "returns Time.current when starts_at string is unparseable" do
      allow(helper).to receive(:params).and_return(
        ActionController::Parameters.new(starts_at: "garbage")
      )

      expect(helper.send(:starts_at)).to be_within(1.second).of(Time.current)
    end

    it "parses a future starts_at string from nested reservation params" do
      future = 1.hour.from_now
      allow(helper).to receive(:params).and_return(
        ActionController::Parameters.new(reservation: { starts_at: future.iso8601 })
      )

      expect(helper.send(:starts_at)).to be_within(1.second).of(future)
    end
  end
end
