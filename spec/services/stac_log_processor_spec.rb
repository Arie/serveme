# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StacLogProcessor do
  let(:reservation) { create(:reservation) }
  let(:processor) { described_class.new(reservation) }
  let(:stac_log_content) { File.read(Rails.root.join('spec', 'fixtures', 'files', 'stac_log.log')) }

  describe '#process_logs' do
    it 'processes logs and sends notifications for detections' do
      discord_notifier = instance_double(StacDiscordNotifier)
      expect(StacDiscordNotifier).to receive(:new).with(reservation).and_return(discord_notifier)
      expect(discord_notifier).to receive(:notify) do |detections, demo_info, demo_timeline|
        # Check detections
        abarigin = detections[76561199543859315]
        expect(abarigin[:name]).to eq('АБАРИГЕН')
        expect(abarigin[:detections].tally).to eq({
          'SilentAim' => 37,
          'OOB cvar/netvar value -1 on var cl_cmdrate' => 4
        })

        aerial = detections[76561199537797286]
        expect(aerial[:name]).to eq('Aerial Denial System')
        expect(aerial[:detections].tally).to eq({
          'CmdNum SPIKE' => 1
        })

        # Check demo info
        expect(demo_info[:filename]).to eq('auto-20250307-1048-ctf_2fort.dem')
        expect(demo_info[:tick]).to eq('144641')

        # Check demo timeline
        expect(demo_timeline.keys).to eq(['auto-20250307-1048-ctf_2fort.dem'])
        expect(demo_timeline['auto-20250307-1048-ctf_2fort.dem']).to eq([
          8411, 10747, 19994, 78659, 78983, 80660, 82420, 88258, 97681, 124684, 144641
        ])
      end

      dir = Dir.mktmpdir
      File.write(File.join(dir, 'stac_log.log'), stac_log_content)
      processor.process_logs(dir)
    ensure
      FileUtils.remove_entry dir if dir
    end

    it 'returns early if no logs are found' do
      dir = Dir.mktmpdir
      expect(StacDiscordNotifier).not_to receive(:new)
      processor.process_logs(dir)
    ensure
      FileUtils.remove_entry dir if dir
    end
  end

  describe '#parse_stac_detections' do
    it 'correctly parses player detections' do
      parsed_detections = processor.send(:parse_stac_detections, stac_log_content)
      expect(parsed_detections.keys.length).to eq(2) # Two unique players

      abarigin = parsed_detections[76561199543859315]
      expect(abarigin[:name]).to eq('АБАРИГЕН')
      expect(abarigin[:detections].tally).to eq({
        'SilentAim' => 37,
        'OOB cvar/netvar value -1 on var cl_cmdrate' => 4
      })

      aerial = parsed_detections[76561199537797286]
      expect(aerial[:name]).to eq('Aerial Denial System')
      expect(aerial[:detections].tally).to eq({
        'CmdNum SPIKE' => 1
      })
    end
  end

  describe '#collect_demo_ticks' do
    it 'collects all demo ticks grouped by filename' do
      demos = processor.send(:collect_demo_ticks, stac_log_content)

      expect(demos.keys).to eq(['auto-20250307-1048-ctf_2fort.dem'])
      expect(demos['auto-20250307-1048-ctf_2fort.dem']).to eq([
        8411, 10747, 19994, 78659, 78983, 80660, 82420, 88258, 97681, 124684, 144641
      ])
    end
  end
end
