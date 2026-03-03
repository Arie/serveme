# typed: false
# frozen_string_literal: true

require "spec_helper"

describe DockerHostReservationCreator do
  let(:user) { create(:user) }
  let(:location) { create(:location) }
  let(:docker_host) { create(:docker_host, location: location) }

  let(:reservation_params) do
    ActionController::Parameters.new(
      password: "testpass",
      rcon: "testrcon",
      server_id: "dh-#{docker_host.id}",
      enable_plugins: "1",
      auto_end: "1",
      starts_at: Time.current.to_s,
      ends_at: 2.hours.from_now.to_s
    ).permit!
  end

  subject do
    described_class.new(
      user: user,
      docker_host_id: docker_host.id,
      reservation_params: reservation_params
    )
  end

  describe "#create!" do
    it "creates a CloudServer and Reservation" do
      expect(CloudServerProvisionWorker).to receive(:perform_async)

      reservation = subject.create!

      expect(reservation).to be_persisted
      expect(reservation.server).to be_a(CloudServer)
      expect(reservation.server.cloud_provider).to eq("remote_docker")
      expect(reservation.server.cloud_location).to eq(docker_host.id.to_s)
      expect(reservation.user).to eq(user)
      expect(reservation.password).to eq("testpass")
    end

    it "updates the cloud server name with the reservation id" do
      expect(CloudServerProvisionWorker).to receive(:perform_async)

      reservation = subject.create!

      expect(reservation.server.name).to include("##{reservation.id}")
    end

    it "schedules provisioning for future reservations" do
      future_time = 1.hour.from_now
      params = reservation_params.merge(starts_at: future_time.iso8601)
      creator = described_class.new(user: user, docker_host_id: docker_host.id, reservation_params: params)

      expect(CloudServerProvisionWorker).to receive(:perform_at).with(
        be_within(5.seconds).of(future_time - 5.minutes),
        instance_of(Integer)
      )

      creator.create!
    end

    it "raises CapacityError when docker host is full" do
      allow_any_instance_of(DockerHost).to receive(:full_during?).and_return(true)

      expect { subject.create! }.to raise_error(DockerHostReservationCreator::CapacityError)
    end

    it "destroys the cloud server if reservation save fails" do
      allow_any_instance_of(Reservation).to receive(:save).and_return(false)

      expect { subject.create! }.to raise_error(DockerHostReservationCreator::ValidationError)
      expect(CloudServer.count).to eq(0)
    end
  end
end
