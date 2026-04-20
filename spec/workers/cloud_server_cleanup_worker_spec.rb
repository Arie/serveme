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

    it "ends reservation and destroys server when ends_at passed over 15 minutes ago but reservation was never ended" do
      old_server = create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago)
      reservation = create(:reservation, server: old_server, ended: false, provisioned: false)
      old_server.update_columns(cloud_reservation_id: reservation.id)
      reservation.update_columns(starts_at: 7.hours.ago, ends_at: 1.hour.ago)

      allow(CloudServerDestroyWorker).to receive(:perform_async)

      described_class.new.perform

      reservation.reload
      expect(reservation.ended).to be true
    end

    it "does not destroy servers whose reservation just ended and is still being processed" do
      old_server = create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago)
      reservation = create(:reservation, server: old_server, ended: false, provisioned: false)
      old_server.update_columns(cloud_reservation_id: reservation.id)
      reservation.update_columns(starts_at: 7.hours.ago, ends_at: 5.minutes.ago)

      expect(CloudServerDestroyWorker).not_to receive(:perform_async)

      described_class.new.perform
    end

    it "does not fail when stranded server has no reservation" do
      create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago, cloud_reservation_id: nil)

      allow(CloudServerDestroyWorker).to receive(:perform_async)

      expect { described_class.new.perform }.not_to raise_error
    end

    it "does not destroy servers with future reservations" do
      old_server = create(:cloud_server, cloud_status: "provisioning", cloud_created_at: 7.hours.ago)
      reservation = create(:reservation, server: old_server, starts_at: 2.hours.from_now, ends_at: 4.hours.from_now, ended: false, provisioned: false)
      old_server.update_columns(cloud_reservation_id: reservation.id)

      expect(CloudServerDestroyWorker).not_to receive(:perform_async)

      described_class.new.perform
    end

    it "does not destroy servers with active reservations that have not ended yet" do
      old_server = create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago)
      reservation = create(:reservation, server: old_server, ended: false, provisioned: true)
      old_server.update_columns(cloud_reservation_id: reservation.id)
      reservation.update_columns(starts_at: 7.hours.ago, ends_at: 1.hour.from_now)

      expect(CloudServerDestroyWorker).not_to receive(:perform_async)

      described_class.new.perform
    end

    it "destroys servers whose reservation has already ended" do
      old_server = create(:cloud_server, cloud_status: "ready", cloud_created_at: 7.hours.ago)
      reservation = create(:reservation, server: old_server, ended: true, provisioned: true)
      old_server.update_columns(cloud_reservation_id: reservation.id)
      reservation.update_columns(starts_at: 7.hours.ago, ends_at: 1.hour.ago)

      expect(CloudServerDestroyWorker).to receive(:perform_async).with(old_server.id)

      described_class.new.perform
    end

    it "does not destroy servers with nil cloud_created_at" do
      create(:cloud_server, cloud_status: "provisioning", cloud_created_at: nil)

      expect(CloudServerDestroyWorker).not_to receive(:perform_async)

      described_class.new.perform
    end
  end
end
