# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Reservations::DockerImageStaleValidator do
  let(:validator) { described_class.new }
  let(:reservation) { Reservation.new(server: server) }

  describe "#validate" do
    context "with a remote_docker server" do
      let(:server) { CloudServer.new(cloud_provider: "remote_docker") }

      it "adds an error when the docker image is stale" do
        allow(DockerImageReadiness).to receive(:stale?).and_return(true)

        validator.validate(reservation)

        expect(reservation.errors[:server]).to be_present
      end

      it "adds no error when the docker image is current" do
        allow(DockerImageReadiness).to receive(:stale?).and_return(false)

        validator.validate(reservation)

        expect(reservation.errors[:server]).to be_empty
      end
    end

    context "with a non-cloud server" do
      let(:server) { Server.new }

      it "adds no error even when the docker image is stale" do
        allow(DockerImageReadiness).to receive(:stale?).and_return(true)

        validator.validate(reservation)

        expect(reservation.errors[:server]).to be_empty
      end
    end

    # Exercises the real DockerImageReadiness -> SiteSetting -> Server.latest_version
    # chain end-to-end rather than stubbing stale?. In the test environment
    # Server.latest_version is 100_000_000.
    context "with real DockerImageReadiness state" do
      let(:server) { CloudServer.new(cloud_provider: "remote_docker") }

      it "adds an error when the recorded image version is behind the latest TF2 version" do
        SiteSetting.set(DockerImageReadiness::VERSION_SETTING_KEY, "50000000")

        validator.validate(reservation)

        expect(reservation.errors[:server]).to be_present
      end

      it "adds no error when no image version has been recorded (fail-open)" do
        SiteSetting.set(DockerImageReadiness::VERSION_SETTING_KEY, nil)

        validator.validate(reservation)

        expect(reservation.errors[:server]).to be_empty
      end
    end
  end
end
