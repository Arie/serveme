# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationChangesWorker do
  let(:reservation) { create(:reservation) }
  let(:server) { reservation.server }
  let(:perform) { ->(changes) { described_class.new.perform(reservation.id, changes.to_json) } }

  before do
    reservation.update_column(:first_map, 'cp_badlands')
    allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
    allow(server).to receive(:update_configuration)
  end

  it 'changes level and reloads the config when map and config changed' do
    expect(server).to receive(:rcon_exec).with('servercfgfile server.cfg; exec reservation.cfg; changelevel cp_badlands')

    perform.call('first_map' => [ 'cp_process_final', 'cp_badlands' ], 'server_config_id' => [ nil, 1 ])
  end

  it 'only changes level when just the map changed' do
    expect(server).to receive(:rcon_exec).with('servercfgfile server.cfg; changelevel cp_badlands')

    perform.call('first_map' => [ 'cp_process_final', 'cp_badlands' ])
  end

  it 'only execs the reservation config for other changes' do
    expect(server).to receive(:update_configuration).with(reservation)
    expect(server).to receive(:rcon_exec).with('exec reservation.cfg')

    perform.call('password' => [ 'old', 'new' ])
  end

  it 'leaves the server alone when the reservation is not running' do
    allow(reservation).to receive(:now?).and_return(false)
    expect(server).not_to receive(:update_configuration)
    expect(server).not_to receive(:rcon_exec)

    perform.call('first_map' => [ 'cp_process_final', 'cp_badlands' ])
  end
end
