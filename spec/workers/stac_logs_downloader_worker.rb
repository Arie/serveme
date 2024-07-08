# frozen_string_literal: true

require 'spec_helper'

describe StacLogsDownloaderWorker do
  let!(:server) { create :server }
  let!(:reservation) { create :reservation, server: server }

  before do
    allow(Server).to receive(:find).with(anything).and_return(server)
    allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
    reservation.stub(server: server)
  end

  it 'downloads the stac logs and inserts them into the database' do
    expect(StacLog.count).to eql 0

    tmp_dir = Dir.mktmpdir
    stac_log = "#{server.tf_dir}/addons/sourcemod/logs/stac/stac_070424.log"

    Dir.should_receive(:mktmpdir).and_return(tmp_dir)
    File.write("#{tmp_dir}/stac.log", 'foobarwidget')

    server.should_receive(:stac_logs).and_return([stac_log])
    server.should_receive(:copy_from_server).with([stac_log], anything)
    server.should_receive(:delete_from_server).with([stac_log])

    described_class.perform_async(reservation.id)

    expect(StacLog.count).to eql 1
  end
end
