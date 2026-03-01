# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StacLogsDownloaderWorker do
  let(:worker) { described_class.new }
  let(:reservation) { create(:reservation) }
  let(:server) { create :server }

  before do
    allow(Server).to receive(:find).with(anything).and_return(server)
    allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
    reservation.stub(server: server)
  end

  describe '#perform' do
    it 'downloads the stac logs and inserts them into the database' do
      expect(StacLog.count).to eql 0

      tmp_dir = Dir.mktmpdir
      stac_log = "#{server.tf_dir}/addons/sourcemod/logs/stac/stac_070424.log"

      Dir.should_receive(:mktmpdir).and_return(tmp_dir)
      File.write("#{tmp_dir}/stac.log", 'foobarwidget')

      server.should_receive(:stac_logs).and_return([ stac_log ])
      server.should_receive(:copy_from_server).with([ stac_log ], anything)
      server.should_receive(:delete_from_server).with([ stac_log ])

      processor = instance_double(StacLogProcessor)
      expect(StacLogProcessor).to receive(:new).with(reservation).and_return(processor)
      expect(processor).to receive(:process_content).with('foobarwidget')
      expect(processor).to receive(:extract_detections).with('foobarwidget').and_return({})

      described_class.perform_async(reservation.id)

      expect(StacLog.count).to eql 1
    end

    it 'saves StacDetection records when detections are found' do
      tmp_dir = Dir.mktmpdir
      stac_log_path = "#{server.tf_dir}/addons/sourcemod/logs/stac/stac_070424.log"

      Dir.should_receive(:mktmpdir).and_return(tmp_dir)
      File.write("#{tmp_dir}/stac.log", 'log with detections')

      server.should_receive(:stac_logs).and_return([ stac_log_path ])
      server.should_receive(:copy_from_server).with([ stac_log_path ], anything)
      server.should_receive(:delete_from_server).with([ stac_log_path ])

      detections = {
        76561198307874162 => {
          name: "Jacob",
          steam_id: "STEAM_0:0:173804217",
          steam_id64: 76561198307874162,
          detections: [ "SilentAim", "SilentAim", "Triggerbot" ]
        }
      }

      processor = instance_double(StacLogProcessor)
      expect(StacLogProcessor).to receive(:new).with(reservation).and_return(processor)
      expect(processor).to receive(:process_content).with('log with detections')
      expect(processor).to receive(:extract_detections).with('log with detections').and_return(detections)

      expect { described_class.perform_async(reservation.id) }.to change(StacDetection, :count).by(2)

      silent_aim = StacDetection.find_by(detection_type: "SilentAim")
      expect(silent_aim.steam_uid).to eq(76561198307874162)
      expect(silent_aim.player_name).to eq("Jacob")
      expect(silent_aim.count).to eq(2)

      triggerbot = StacDetection.find_by(detection_type: "Triggerbot")
      expect(triggerbot.count).to eq(1)
    end

    it 'returns early if no logs are found' do
      server.should_receive(:stac_logs).and_return([])
      expect(StacLogProcessor).not_to receive(:new)
      described_class.perform_async(reservation.id)
    end
  end
end
