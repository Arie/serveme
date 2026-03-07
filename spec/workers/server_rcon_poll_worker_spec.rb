# typed: false
# frozen_string_literal: true

require "spec_helper"

describe ServerRconPollWorker do
  let(:server) { create(:server) }
  let(:reservation) { create(:reservation, server: server, ready_at: nil) }
  let(:started_at) { Time.current.iso8601 }

  before do
    allow_any_instance_of(Server).to receive(:rcon_exec).and_return(nil)
  end

  describe "#perform" do
    it "sets ready_at when rcon responds" do
      allow_any_instance_of(Server).to receive(:rcon_exec).with("status").and_return("hostname: test")

      subject.perform(reservation.id, started_at)

      reservation.reload
      expect(reservation.ready_at).to be_present
      expect(reservation.reservation_statuses.last.status).to eq("Server ready")
    end

    it "retries when rcon is not ready" do
      allow_any_instance_of(Server).to receive(:rcon_exec).with("status").and_raise(Errno::ECONNREFUSED)

      expect(ServerRconPollWorker).to receive(:perform_in).with(3.seconds, reservation.id, started_at)

      subject.perform(reservation.id, started_at)
    end

    it "gives up after MAX_POLL_TIME" do
      old_started_at = 3.minutes.ago.iso8601
      allow_any_instance_of(Server).to receive(:rcon_exec).with("status").and_raise(Errno::ECONNREFUSED)

      expect(ServerRconPollWorker).not_to receive(:perform_in)

      subject.perform(reservation.id, old_started_at)
    end

    it "skips when ready_at already set" do
      reservation.update_columns(ready_at: Time.current)

      subject.perform(reservation.id, started_at)

      # Should not have created any status updates
      expect(reservation.reservation_statuses.where(status: "Server ready")).to be_empty
    end

    it "skips when reservation ended" do
      reservation.update_columns(ended: true)

      subject.perform(reservation.id, started_at)

      expect(reservation.reservation_statuses.where(status: "Server ready")).to be_empty
    end

    it "skips for cloud servers" do
      cloud_server = create(:cloud_server)
      cloud_reservation = create(:reservation, server: cloud_server, ready_at: nil)

      subject.perform(cloud_reservation.id, started_at)

      expect(cloud_reservation.reservation_statuses.where(status: "Server ready")).to be_empty
    end
  end
end
