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
      expect(discord_notifier).to receive(:notify) do |detections|
        # Check detections
        abarigin = detections[76561199543859315]
        expect(abarigin[:name]).to eq('АБАРИГЕН')
        expect(abarigin[:detections].tally).to eq({
          'SilentAim' => 37,
          'OOB cvar/netvar value -1 on var cl_cmdrate' => 4
        })

        aerial = detections[76561198169848874]
        expect(aerial[:name]).to eq('Tieez')
        expect(aerial[:detections].tally).to eq({
          'Triggerbot' => 8
        })

        fume = detections[76561197960476801]
        expect(fume[:name]).to eq('fume')
        expect(fume[:detections].tally).to eq({
          'SilentAim' => 1
        })

        bobimarley = detections[76561198332416145]
        expect(bobimarley[:name]).to eq('Marqui2156')
        expect(bobimarley[:detections].tally).to eq({
          'Aimsnap' => 6
        })

        unico = detections[76561198071993023]
        expect(unico[:name]).to eq('Unico')
        expect(unico[:detections].tally).to eq({
          'CmdNum SPIKE' => 1
        })
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

  describe '#process_content' do
    it 'processes content and sends notifications for detections' do
      discord_notifier = instance_double(StacDiscordNotifier)
      expect(StacDiscordNotifier).to receive(:new).with(reservation).and_return(discord_notifier)
      expect(discord_notifier).to receive(:notify) do |detections|
        # Check detections
        unico = detections[76561198071993023]
        expect(unico[:name]).to eq('Unico')
        expect(unico[:detections].tally).to eq({
          'CmdNum SPIKE' => 1
        })
      end

      processor.process_content(stac_log_content)
    end
  end
end
