# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerRconPollWorker do
  let(:reservation) { create(:reservation, server: cloud_server, provisioned: false) }
  let(:cloud_server) { create(:cloud_server, cloud_status: "ready", cloud_created_at: 1.minute.ago) }

  before do
    cloud_server.update_columns(cloud_reservation_id: reservation.id)
  end

  describe "#perform" do
    it "marks reservation as provisioned when rcon responds" do
      allow(cloud_server).to receive(:rcon_exec).with("status").and_return("hostname: serveme cloud server\nplayers: 0")
      allow(CloudServer).to receive(:find_by).and_return(cloud_server)
      allow_any_instance_of(CloudServer).to receive(:rcon_exec).with("status").and_return("hostname: serveme cloud server")

      described_class.new.perform(reservation.id)

      reservation.reload
      expect(reservation.provisioned).to eq(true)
      expect(reservation.ready_at).to be_present
    end

    it "retries when rcon connection is refused" do
      allow_any_instance_of(CloudServer).to receive(:rcon_exec).with("status").and_raise(Errno::ECONNREFUSED)
      expect(CloudServerRconPollWorker).to receive(:perform_in).with(3.seconds, reservation.id)

      described_class.new.perform(reservation.id)

      expect(reservation.reload.provisioned).to eq(false)
    end

    it "retries when rcon returns empty result" do
      allow_any_instance_of(CloudServer).to receive(:rcon_exec).with("status").and_return(nil)
      expect(CloudServerRconPollWorker).to receive(:perform_in).with(3.seconds, reservation.id)

      described_class.new.perform(reservation.id)

      expect(reservation.reload.provisioned).to eq(false)
    end

    it "retries on SteamCondenser errors" do
      allow_any_instance_of(CloudServer).to receive(:rcon_exec).with("status").and_raise(SteamCondenser::Error.new("timeout"))
      expect(CloudServerRconPollWorker).to receive(:perform_in).with(3.seconds, reservation.id)

      described_class.new.perform(reservation.id)
    end

    it "stops polling when reservation is already provisioned" do
      reservation.update_columns(provisioned: true)
      expect_any_instance_of(CloudServer).not_to receive(:rcon_exec)
      expect(CloudServerRconPollWorker).not_to receive(:perform_in)

      described_class.new.perform(reservation.id)
    end

    it "stops polling when reservation has ended" do
      reservation.update_columns(ended: true)
      expect_any_instance_of(CloudServer).not_to receive(:rcon_exec)
      expect(CloudServerRconPollWorker).not_to receive(:perform_in)

      described_class.new.perform(reservation.id)
    end

    it "stops polling when cloud server is destroyed" do
      cloud_server.update_columns(cloud_status: "destroyed")
      expect_any_instance_of(CloudServer).not_to receive(:rcon_exec)
      expect(CloudServerRconPollWorker).not_to receive(:perform_in)

      described_class.new.perform(reservation.id)
    end

    it "gives up polling after too long" do
      cloud_server.update_columns(cloud_created_at: 15.minutes.ago)
      allow_any_instance_of(CloudServer).to receive(:rcon_exec).with("status").and_raise(Errno::ECONNREFUSED)
      expect(CloudServerRconPollWorker).not_to receive(:perform_in)

      described_class.new.perform(reservation.id)
    end
  end
end
