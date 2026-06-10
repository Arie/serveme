# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe IAmFeelingLucky do
  let(:user) { create :user }
  subject { IAmFeelingLucky.new(user) }

  context 'without a previous reservation' do
    it 'finds an available server and builds a reservation' do
      available_server = create :server

      reservation = subject.build_reservation

      reservation.server.should
      reservation.rcon.should be_present
      reservation.password.should be_present
      reservation.tv_password.should be_present
      reservation.auto_end.should be true
    end
  end

  context 'with a previous reservation' do
    it 'tries to make a reservation with same settings and server again' do
      previous_reservation = create :reservation, user: user, rcon: 'the_rcon'
      previous_reservation.update_column(:ends_at, 1.hour.ago)

      reservation = subject.build_reservation

      reservation.server.should
      previous_reservation.server
      reservation.rcon.should == previous_reservation.rcon
    end

    it 'falls back to a server on the same host' do
      previous_reservation = create :reservation, user: user, rcon: 'the_rcon'
      previous_reservation.update_column(:starts_at, 2.hours.ago)
      previous_reservation.update_column(:ends_at,   1.hour.ago)
      new_reservation_taking_my_previous_server = create :reservation, server: previous_reservation.server
      fallback_server_on_same_host = create :server, ip: previous_reservation.server.ip, port: 1337
      some_other_server = create(:server, ip: 'foo.bar')

      reservation = subject.build_reservation

      reservation.server.should == fallback_server_on_same_host
    end

    it 'falls back to a server in the same location if all on host are taken' do
      previous_reservation = create :reservation, user: user, rcon: 'the_rcon'
      previous_reservation.update_column(:starts_at, 2.hours.ago)
      previous_reservation.update_column(:ends_at,   1.hour.ago)
      new_reservation_taking_my_previous_server = create :reservation, server: previous_reservation.server
      fallback_server_on_same_host              = create :server, ip: previous_reservation.server.ip, port: 1337
      new_reservation_taking_fallback_server    = create :reservation, server: fallback_server_on_same_host

      fallback_server_in_same_location  = create(:server, ip: '176.9.138.144', location_id: previous_reservation.server.location_id)
      fallback_server_in_other_location = create(:server, ip: '176.9.138.145', location: build(:location))

      reservation = subject.build_reservation

      reservation.server.should == fallback_server_in_same_location
    end

    it 'falls back to any available server in case the rest is taken' do
      previous_reservation = create :reservation, user: user, rcon: 'the_rcon'
      previous_reservation.update_column(:starts_at, 2.hours.ago)
      previous_reservation.update_column(:ends_at,   1.hour.ago)
      new_reservation_taking_my_previous_server = create :reservation, server: previous_reservation.server

      create :server, ip: '3.3.3.3', position: 10
      some_fallback_server = create :server, ip: '3.3.3.3', position: 1
      create :server, ip: '3.3.3.3', position: 10

      reservation = subject.build_reservation

      reservation.server.should == some_fallback_server
    end
  end

  context 'when no regular server is available' do
    before { allow(DockerImageReadiness).to receive(:stale?).and_return(false) }

    it 'has no server to build a reservation with' do
      create(:docker_host)

      expect(subject.first_available_server).to be_nil
      expect(subject.build_reservation.server).to be_nil
    end

    it 'falls back to a docker host with free capacity' do
      docker_host = create(:docker_host)

      expect(subject.available_docker_host).to eq(docker_host)
    end

    it 'returns no docker host when the image is stale' do
      create(:docker_host)
      allow(DockerImageReadiness).to receive(:stale?).and_return(true)

      expect(subject.available_docker_host).to be_nil
    end

    it 'prefers a docker host on the same machine as the previous server (by hostname)' do
      previous_reservation = create :reservation, user: user
      previous_reservation.update_column(:ends_at, 1.hour.ago)
      previous_server = previous_reservation.server
      create(:docker_host, location: previous_server.location)
      same_host = create(:docker_host, hostname: previous_server.ip, location: build(:location))

      expect(subject.available_docker_host).to eq(same_host)
    end

    it 'matches a remote-docker previous server back to its docker host by hostname' do
      docker_host = create(:docker_host, hostname: 'chi3.serveme.tf')
      previous_cloud_server = create(:cloud_server, cloud_provider: 'remote_docker', cloud_location: docker_host.id.to_s, ip: '1.2.3.4', location: build(:location))
      previous_reservation = create :reservation, user: user, server: previous_cloud_server
      previous_reservation.update_column(:ends_at, 1.hour.ago)
      create(:docker_host, hostname: 'other.serveme.tf', location: build(:location))

      expect(subject.available_docker_host).to eq(docker_host)
    end

    it 'prefers a docker host in the previous reservation location when no host matches' do
      previous_reservation = create :reservation, user: user
      previous_reservation.update_column(:ends_at, 1.hour.ago)
      create(:docker_host, location: build(:location))
      same_location_host = create(:docker_host, location: previous_reservation.server.location)

      expect(subject.available_docker_host).to eq(same_location_host)
    end

    it 'reuses the previous reservation settings in the docker host params, without a server' do
      previous_reservation = create :reservation, user: user, rcon: 'the_rcon'
      previous_reservation.update_column(:ends_at, 1.hour.ago)

      params = subject.docker_host_reservation_params

      expect(params[:rcon]).to eq('the_rcon')
      expect(params[:server]).to be_nil
      expect(params[:server_id]).to be_nil
      expect(params[:starts_at]).to be_present
      expect(params[:ends_at]).to be_present
    end
  end
end
