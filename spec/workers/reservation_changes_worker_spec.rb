# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationChangesWorker do
  let(:reservation) { create(:reservation) }
  let(:server) { reservation.server }
  let(:perform) { ->(changed_attributes) { described_class.new.perform(reservation.id, changed_attributes) } }

  before do
    reservation.update_column(:first_map, 'cp_badlands')
    allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
    allow(server).to receive(:update_configuration)
  end

  it 'changes level and reloads the config when map and config changed' do
    expect(server).to receive(:rcon_exec).with('servercfgfile server.cfg; exec reservation.cfg; changelevel cp_badlands')

    perform.call(%w[first_map server_config_id])
  end

  it 'only changes level when just the map changed' do
    expect(server).to receive(:rcon_exec).with('servercfgfile server.cfg; changelevel cp_badlands')

    perform.call(%w[first_map])
  end

  it 'only execs the reservation config for other changes' do
    expect(server).to receive(:update_configuration).with(reservation)
    expect(server).to receive(:rcon_exec).with('exec reservation.cfg')

    perform.call(%w[password])
  end

  it 'leaves the server alone when the reservation is not running' do
    allow(reservation).to receive(:now?).and_return(false)
    expect(server).not_to receive(:update_configuration)
    expect(server).not_to receive(:rcon_exec)

    perform.call(%w[first_map])
  end
end
