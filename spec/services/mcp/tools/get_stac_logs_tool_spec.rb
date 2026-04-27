# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::GetStacLogsTool do
  it "exposes correct tool metadata" do
    expect(described_class.tool_name).to eq("get_stac_logs")
    expect(described_class.description).to be_a(String).and(be_present)
    expect(described_class.required_role).to eq(:league_admin)

    schema = described_class.input_schema
    expect(schema[:type]).to eq("object")
    expect(schema[:properties].keys).to include(:reservation_id, :include_contents)
    expect(schema[:required]).to include("reservation_id")
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }
    let(:reservation) { create(:reservation, server: create(:server)) }

    it "returns errors for missing or unknown reservation_id" do
      expect(tool.execute({})[:error]).to match(/reservation_id is required/i)
      expect(tool.execute(reservation_id: 999_999_999)[:error]).to match(/not found/i)
    end

    it "returns empty arrays when reservation has no stac data" do
      result = tool.execute(reservation_id: reservation.id)

      expect(result).to include(
        reservation_id: reservation.id,
        stac_logs: [],
        detections: []
      )
    end

    context "with stac logs and detections" do
      let(:stac_log_contents) do
        <<~LOG
          <17:58:41>#{' '}

          ----------

          [StAC] Possible triggerbot detection on THE GIGGLING GOONER.
          Detections so far: 1. Type: +attack2
          <17:58:41>#{' '}
           Player: THE GIGGLING GOONER<16><[U:1:955780059]><>
           StAC cached SteamID: STEAM_0:1:477890029
          <17:58:41>#{' '}
          Network:
           90.32 ms ping
           0.00 loss
          <17:58:41> Weapon used: tf_weapon_pipebomblauncher
          <18:02:10>#{' '}

          ----------
        LOG
      end

      let!(:stac_log) do
        create(:stac_log,
          reservation: reservation,
          filename: "stac_100525.log",
          contents: stac_log_contents,
          filesize: stac_log_contents.bytesize)
      end

      let!(:detection) do
        create(:stac_detection,
          reservation: reservation,
          stac_log: stac_log,
          steam_uid: 76561198911545787,
          player_name: "THE GIGGLING GOONER",
          steam_id: "STEAM_0:1:477890029",
          detection_type: "Triggerbot",
          count: 1)
      end

      it "returns log metadata and detection summary, omitting contents by default" do
        result = tool.execute(reservation_id: reservation.id)

        expect(result[:stac_logs]).to contain_exactly(
          a_hash_including(id: stac_log.id, filename: "stac_100525.log", filesize: stac_log_contents.bytesize)
        )
        expect(result[:stac_logs].first).not_to have_key(:contents)
        expect(result[:detections]).to contain_exactly(
          a_hash_including(
            steam_uid: "76561198911545787",
            player_name: "THE GIGGLING GOONER",
            steam_id: "STEAM_0:1:477890029",
            detection_type: "Triggerbot",
            count: 1,
            stac_log_id: stac_log.id
          )
        )
      end

      it "includes raw contents only when include_contents is true" do
        with_contents = tool.execute(reservation_id: reservation.id, include_contents: true)
        without_contents = tool.execute(reservation_id: reservation.id, include_contents: false)

        expect(with_contents[:stac_logs].first[:contents]).to eq(stac_log_contents)
        expect(with_contents[:stac_logs].first[:contents]).to include("Possible triggerbot detection on THE GIGGLING GOONER")
        expect(without_contents[:stac_logs].first).not_to have_key(:contents)
      end
    end

    it "returns all logs and detections when reservation has multiple of each" do
      create(:stac_log, reservation: reservation, filename: "stac_one.log")
      create(:stac_log, reservation: reservation, filename: "stac_two.log")
      create(:stac_detection, reservation: reservation, steam_uid: 76561198121413721, detection_type: "SilentAim", count: 4)
      create(:stac_detection, reservation: reservation, steam_uid: 76561198121413721, detection_type: "Triggerbot", count: 7)
      create(:stac_detection, reservation: reservation, steam_uid: 76561199374476933, detection_type: "CmdNum SPIKE", count: 3)

      result = tool.execute(reservation_id: reservation.id)

      expect(result[:stac_logs].map { |l| l[:filename] }).to contain_exactly("stac_one.log", "stac_two.log")
      expect(result[:detections].map { |d| [ d[:steam_uid], d[:detection_type] ] }).to contain_exactly(
        [ "76561198121413721", "SilentAim" ],
        [ "76561198121413721", "Triggerbot" ],
        [ "76561199374476933", "CmdNum SPIKE" ]
      )
    end
  end
end
