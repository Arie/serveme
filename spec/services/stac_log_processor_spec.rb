# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StacLogProcessor do
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
    # This context uses the stac_log.log fixture
    context "with fixture log" do
      let(:reservation) { create(:reservation) }
      let(:processor) { described_class.new(reservation) }
      let(:stac_log_content) { File.read(Rails.root.join('spec', 'fixtures', 'files', 'stac_log.log')) }

      before do
        # Allow any SteamID conversion for this context
        allow(SteamCondenser::Community::SteamId).to receive(:steam_id_to_community_id).and_call_original
      end

      it 'processes content and sends notifications for detections' do
        discord_notifier = instance_double(StacDiscordNotifier)
        expect(StacDiscordNotifier).to receive(:new).with(reservation).and_return(discord_notifier)
        expect(discord_notifier).to receive(:notify) do |detections|
          # Check detections (example for Unico)
          unico = detections[76561198071993023]
          expect(unico[:name]).to eq('Unico')
          expect(unico[:detections].tally).to eq({
            'CmdNum SPIKE' => 1
          })
        end

        processor.process_content(stac_log_content)
      end
    end

    # This context uses the specific Jacob log content for the bug reproduction
    context "with specific Jacob log content" do
      let(:reservation) { instance_double(Reservation, id: 1_481_044) }
      let(:log_content) do
        <<~LOG
          <17:39:20>

          ----------

          [StAC] Possible triggerbot detection on Jacob.
          Detections so far: 1. Type: +attack0
          <17:39:20>
           Player: Jacob<4><[U:1:347608434]><>
           StAC cached SteamID: STEAM_0:0:173804217
          <17:39:20>
          Network:
           87.79 ms ping
           0.00 loss
           0.00 inchoke
           1.61 outchoke
           1.61 totalchoke
           273.41 kbps rate
           133.55 pps rate
          <17:39:20>
          More network:
           Approx client cmdrate: ≈67 cmd/sec
           Approx server tickrate: ≈67 tick/sec
           Failing lag check? no
           SequentialCmdnum? yes
          <17:39:20>
          Angles:
           angles0: x 15.848145 y -119.282287
           angles1: x 17.302253 y -109.280670
           angles2: x 16.871150 y -131.954299
           angles3: x 17.201152 y -136.607284
           angles4: x 17.531154 y -140.501296      <17:39:20>
          Client eye positions:
           eyepos 0: x -2490.025 y 610.556 z 357.723
           eyepos 1: x -2486.152 y 612.434 z 358.788
          <17:39:20>
          Previous cmdnums:
          0 7188
          1 7187
          2 7186
          3 7185
          4 7184
          <17:39:20>
          Previous tickcounts:
          0 110626
          1 110625
          2 110624
          3 110623
          4 110622
          <17:39:20>
          Current server tick:
          110632
          <17:39:20>
          Mouse Movement (sens weighted):
           abs(x): 8299
           abs(y): 12604
          Mouse Movement (unweighted):
           x: 12449
           y: 18906
          Client Sens:
           1.500000
          <17:39:20>
          Previous buttons - use https://sapphonie.github.io/flags.html to convert to readable input
          0 1032
          1 1033
          2 1032
          3 1032
          4 1032
          <17:39:20> Weapon used: tf_weapon_knife
          <17:39:39>

          ----------

          [StAC] Possible triggerbot detection on Jacob.
          Detections so far: 2. Type: +attack0
          <17:39:39>
           Player: Jacob<4><[U:1:347608434]><>
           StAC cached SteamID: STEAM_0:0:173804217
          <17:39:39>
          Network:
           86.90 ms ping
           0.00 loss
           0.00 inchoke
           0.00 outchoke
           0.00 totalchoke
           279.64 kbps rate
           135.38 pps rate
          <17:39:39>
          More network:
           Approx client cmdrate: ≈67 cmd/sec
           Approx server tickrate: ≈67 tick/sec
           Failing lag check? no
           SequentialCmdnum? yes
          <17:39:39>
          Angles:
           angles0: x 54.227188 y 26.379961
           angles1: x 63.424617 y 141.126495
           angles2: x 49.640190 y -1.175039
           angles3: x 47.594188 y -7.181038
           angles4: x 46.637184 y -9.161038
          <17:39:39>
          Client eye positions:
           eyepos 0: x -1146.652 y 354.310 z 412.346
           eyepos 1: x -1149.201 y 350.950 z 415.320
          <17:39:39>
          Previous cmdnums:
          0 8397
          1 8396
          2 8395
          3 8394
          4 8393
          <17:39:39>
          Previous tickcounts:
          0 111835
          1 111834
          2 111833
          3 111832
          4 111831
          <17:39:39>
          Current server tick:
          111840
          <17:39:39>
          Mouse Movement (sens weighted):
           abs(x): 17559
           abs(y): 12605
          Mouse Movement (unweighted):
           x: 26338
           y: 18908
          Client Sens:
           1.500000
          <17:39:39>
          Previous buttons - use https://sapphonie.github.io/flags.html to convert to readable input
          0 520
          1 513
          2 512
          3 512
          4 512
          <17:39:39> Weapon used: tf_weapon_knife
          <17:43:05>

          ----------

                      [StAC] SilentAim detection of 22.80° on Jacob.
          Detections so far: 1 norecoil = no
          <17:43:05>
           Player: Jacob<4><[U:1:347608434]><>
           StAC cached SteamID: STEAM_0:0:173804217
          <17:43:05>
          Network:
           86.08 ms ping
           0.00 loss
           0.00 inchoke
           0.00 outchoke
           0.00 totalchoke
           346.63 kbps rate
           134.90 pps rate
          <17:43:05>
          More network:
           Approx client cmdrate: ≈67 cmd/sec
           Approx server tickrate: ≈67 tick/sec
           Failing lag check? no
           SequentialCmdnum? yes
          <17:43:05>
          Angles:
           angles0: x 43.022632 y 93.486930
           angles1: x 20.229125 y 92.627754
           angles2: x 43.022632 y 93.486930
           angles3: x 13.893123 y 92.363746
           angles4: x 43.022632 y 93.486930
          <17:43:05>
          Client eye positions:
           eyepos 0: x -1464.330 y -929.059 z 235.031
           eyepos 1: x -1464.330 y -929.059 z 235.031
          <17:43:05>
          Previous cmdnums:
          0 22180
          1 22179
          2 22178
          3 22177
          4 22176
          <17:43:05>
          Previous tickcounts:
          0 125607
          1 125606
          2 125605
          3 125604
          4 125603
          <17:43:05>
          Current server tick:
          125613
          <17:43:05>
          Mouse Movement (sens weighted):
           abs(x): 16560
           abs(y): 12622
          Mouse Movement (unweighted):
           x: -24840
           y: 18933
          Client Sens:
           1.500000
          <17:43:05>
          Previous buttons - use https://sapphonie.github.io/flags.html to convert to readable input
          0 1
          1 1
          2 1
          3 1
          4 1
          <17:43:05>

          ----------

                      [StAC] SilentAim detection of 17.39° on Jacob.
          Detections so far: 2 norecoil = no
          <17:43:05>
           Player: Jacob<4><[U:1:347608434]><>
           StAC cached SteamID: STEAM_0:0:173804217
          <17:43:05>
          Network:
           86.08 ms ping
           0.00 loss
           0.00 inchoke
           0.00 outchoke
           0.00 totalchoke
           346.63 kbps rate
           134.90 pps rate
          <17:43:05>
          More network:
           Approx client cmdrate: ≈67 cmd/sec
           Approx server tickrate: ≈67 tick/sec
           Failing lag check? no
           SequentialCmdnum? yes
          <17:43:05>
          Angles:
           angles0: x 43.022632 y 93.486930
           angles1: x 25.674125 y 92.264762
           angles2: x 43.022632 y 93.486930
           angles3: x 20.229125 y 92.627754
           angles4: x 43.022632 y 93.486930
          <17:43:05>
          Client eye positions:
           eyepos 0: x -1464.330 y -929.059 z 235.031
           eyepos 1: x -1464.330 y -929.059 z 235.031
          <17:43:05>
          Previous cmdnums:
          0 22182
          1 22181
          2 22180
          3 22179
          4 22178
          <17:43:05>
          Previous tickcounts:
          0 125609
          1 125608
          2 125607
          3 125606
          4 125605
          <17:43:05>
          Current server tick:
          125615
          <17:43:05>
          Mouse Movement (sens weighted):
           abs(x): 16400
           abs(y): 12622
          Mouse Movement (unweighted):
           x: -24600
           y: 18933
          Client Sens:
           1.500000
          <17:43:05>
          Previous buttons - use https://sapphonie.github.io/flags.html to convert to readable input
          0 1
          1 1
          2 1
          3 1
          4 1
          # ... rest of the log omitted for brevity, but the structure continues
          # Include enough lines to ensure multiple detection types are present
        LOG
      end
      let(:processor) { described_class.new(reservation) }
      let(:notifier_double) { instance_double(StacDiscordNotifier, notify: nil) }

      before do
        # Stub Steam ID conversion
        allow(SteamCondenser::Community::SteamId).to receive(:steam_id_to_community_id)
                                                    .with("STEAM_0:0:173804217")
                                                    .and_return(76_561_198_307_874_162)
        # Stub the notifier
        allow(StacDiscordNotifier).to receive(:new).with(reservation).and_return(notifier_double)
      end

      it 'correctly reports distinct aim detections' do
        processor.process_content(log_content)
        expected_detections = {
          76_561_198_307_874_162 => {
            name: "Jacob",
            steam_id: "STEAM_0:0:173804217",
            steam_id64: 76_561_198_307_874_162,
            detections: [ "Triggerbot", "Triggerbot", "SilentAim", "SilentAim" ]
          }
        }
        expect(notifier_double).to have_received(:notify).with(expected_detections)
      end
    end
  end
end
