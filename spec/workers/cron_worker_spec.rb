# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe CronWorker do
  let(:reservation) { create :reservation }

  before do
    condenser = double.as_null_object
    server = double(:server, id: 1, rcon_auth: true, rcon_disconnect: true, condenser: condenser)
    reservation.stub(server: server)
    allow(ServerMetric).to receive(:new)
  end

  describe '#end_past_reservations' do
    it 'tells unended past reservations to end' do
      reservation.update_column(:ends_at, 1.minute.ago)
      reservation.update_column(:provisioned, true)
      ReservationWorker.should_receive(:perform_async).with(reservation.id, 'end')
      CronWorker.perform_async
    end
  end

  describe '#start_active_reservations' do
    it 'tells unstarted active reservations to start' do
      reservation.update_column(:starts_at, 1.minute.ago)
      reservation.update_column(:provisioned, false)
      ReservationWorker.should_receive(:perform_async).with(reservation.id, 'start')
      CronWorker.perform_async
    end
  end

  describe '#check_active_reservations' do
    it 'triggers the active reservation checker worker for active reservations' do
      reservation.update_attribute(:provisioned, true)
      reservation.update_attribute(:ended,       false)
      ActiveReservationsCheckerWorker.should_receive(:perform_async).with([ reservation.id ])
      CronWorker.perform_async
    end
  end

  describe '#broadcast_players_update' do
    let(:worker) { CronWorker.new }
    let(:servers_with_players) { [] }

    before do
      allow(CurrentPlayersService).to receive(:expire_cache)
      allow(CurrentPlayersService).to receive(:all_servers_with_current_players).and_return(servers_with_players)
      allow(CurrentPlayersService).to receive(:distance_unit_for_region).and_return('km')
    end

    it 'broadcasts to both regular and admin streams' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "players",
        target: "players-content",
        partial: "players/players_content",
        locals: {
          servers_with_players: servers_with_players,
          distance_unit: 'km'
        }
      )

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "admin-players",
        target: "admin-players-content",
        partial: "players/admin_players_content",
        locals: {
          servers_with_players: servers_with_players,
          distance_unit: 'km'
        }
      )

      worker.broadcast_players_update
    end

    it 'expires the current players cache before broadcasting' do
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

      expect(CurrentPlayersService).to receive(:expire_cache)

      worker.broadcast_players_update
    end
  end
end
