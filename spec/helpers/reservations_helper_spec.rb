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
end
