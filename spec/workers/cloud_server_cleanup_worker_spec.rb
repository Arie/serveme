# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudServerCleanupWorker do
  describe "#perform" do
    it "enqueues destroy for stranded provisioning servers older than 6 hours" do
      old_server = create(:cloud_server, cloud_status: "provisioning", cloud_created_at: 7.hours.ago)

      expect(CloudServerDestroyWorker).to receive(:perform_async).with(old_server.id)

      described_class.new.perform
    end

    it "enqueues destroy for stranded ssh_ready servers older than 6 hours" do
      old_server = create(:cloud_server, cloud_status: "ssh_ready", cloud_created_at: 7.hours.ago)

      expect(CloudServerDestroyWorker).to receive(:perform_async).with(old_server.id)

      described_class.new.perform
    end

    it "enqueues destroy for stranded ready servers older than 6 hours" do
      old_server = create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago)

      expect(CloudServerDestroyWorker).to receive(:perform_async).with(old_server.id)

      described_class.new.perform
    end

    it "does not destroy recently created servers" do
      create(:cloud_server, cloud_status: "provisioning", cloud_created_at: 1.hour.ago)

      expect(CloudServerDestroyWorker).not_to receive(:perform_async)

      described_class.new.perform
    end

    it "does not destroy already-destroyed servers" do
      create(:cloud_server, cloud_status: "destroyed", cloud_created_at: 7.hours.ago)

      expect(CloudServerDestroyWorker).not_to receive(:perform_async)

      described_class.new.perform
    end

    it "ends the associated reservation when destroying a stranded server" do
      old_server = create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago)
      reservation = create(:reservation, server: old_server, ended: false, provisioned: false)
      old_server.update_columns(cloud_reservation_id: reservation.id)

      allow(CloudServerDestroyWorker).to receive(:perform_async)

      described_class.new.perform

      reservation.reload
      expect(reservation.ended).to be true
    end

    it "does not fail when stranded server has no reservation" do
      create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago, cloud_reservation_id: nil)

      allow(CloudServerDestroyWorker).to receive(:perform_async)

      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
