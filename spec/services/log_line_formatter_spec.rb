# typed: false
# frozen_string_literal: true

require "spec_helper"

describe LogLineFormatter do
  describe "#format" do
    context "with a kill event" do
      let(:line) do
        'L 02/15/2013 - 00:14:52: "Aka Game<4><STEAM_0:0:5253998><Red>" killed "ser mais leve<6><STEAM_0:0:41722710><Blue>" with "scattergun" (attacker_position "896 -1290 256") (victim_position "726 -1245 297")'
      end
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns kill event type" do
        expect(formatted[:type]).to eq(:kill)
      end

      it "parses the timestamp" do
        expect(formatted[:timestamp]).to eq(Time.local(2013, 2, 15, 0, 14, 52))
      end

      it "extracts player information" do
        expect(formatted[:event].player.name).to eq("Aka Game")
        expect(formatted[:event].player.team).to eq("Red")
      end

      it "extracts target information" do
        expect(formatted[:event].target.name).to eq("ser mais leve")
        expect(formatted[:event].target.team).to eq("Blue")
      end

      it "extracts weapon" do
        expect(formatted[:event].weapon).to eq("scattergun")
      end

      it "includes position data in raw output" do
        expect(formatted[:raw]).to include("attacker_position")
        expect(formatted[:raw]).to include("victim_position")
      end
    end

    context "with a chat event" do
      let(:line) do
        'L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!extend"'
      end
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns say event type" do
        expect(formatted[:type]).to eq(:say)
      end

      it "extracts player name" do
        expect(formatted[:event].player.name).to eq("Arie - serveme.tf")
      end

      it "extracts message" do
        expect(formatted[:event].message).to eq("!extend")
      end
    end

    context "with a connect event" do
      let(:line) do
        'L 02/15/2013 - 00:13:12: "Aka Game<4><STEAM_0:0:5253998><>" connected, address "0.0.0.0:27005"'
      end
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns connect event type" do
        expect(formatted[:type]).to eq(:connect)
      end

      it "extracts player name" do
        expect(formatted[:event].player.name).to eq("Aka Game")
      end
    end

    context "with an unknown event" do
      let(:line) { "Some random log line that doesn't match any pattern" }
      let(:formatter) { described_class.new(line) }
      let(:formatted) { formatter.format }

      it "returns unknown event type" do
        expect(formatted[:type]).to eq(:unknown)
      end
    end
  end

  describe "#event_type" do
    # Characterization test: locks the exact event-class -> symbol mapping
    # (including subclass-ordering behaviour) before refactoring the giant
    # case statement into a lookup table. Uses real (allocated) event
    # instances so is_a?-based dispatch behaves exactly as in production.
    {
      TF2LineParser::Events::Kill => :kill,
      TF2LineParser::Events::Say => :say,
      TF2LineParser::Events::TeamSay => :team_say,
      TF2LineParser::Events::Connect => :connect,
      TF2LineParser::Events::Disconnect => :disconnect,
      TF2LineParser::Events::PointCapture => :point_capture,
      TF2LineParser::Events::CaptureBlock => :capture_block,
      TF2LineParser::Events::RoundWin => :round_win,
      TF2LineParser::Events::RoundStart => :round_start,
      TF2LineParser::Events::RoundStalemate => :round_stalemate,
      TF2LineParser::Events::RoundLength => :round_length,
      TF2LineParser::Events::CurrentScore => :current_score,
      TF2LineParser::Events::FinalScore => :final_score,
      TF2LineParser::Events::MatchEnd => :match_end,
      TF2LineParser::Events::RconCommand => :rcon,
      TF2LineParser::Events::ConsoleSay => :console_say,
      TF2LineParser::Events::Suicide => :suicide,
      TF2LineParser::Events::RoleChange => :role_change,
      TF2LineParser::Events::Domination => :domination,
      TF2LineParser::Events::Revenge => :revenge,
      TF2LineParser::Events::PickupItem => :pickup_item,
      TF2LineParser::Events::AirshotHeal => :airshot_heal,
      TF2LineParser::Events::Heal => :heal,
      TF2LineParser::Events::ChargeDeployed => :charge_deployed,
      TF2LineParser::Events::ChargeReady => :charge_ready,
      TF2LineParser::Events::ChargeEnded => :charge_ended,
      TF2LineParser::Events::LostUberAdvantage => :lost_uber_advantage,
      TF2LineParser::Events::EmptyUber => :empty_uber,
      TF2LineParser::Events::FirstHealAfterSpawn => :first_heal_after_spawn,
      TF2LineParser::Events::PlayerExtinguished => :player_extinguished,
      TF2LineParser::Events::JoinedTeam => :joined_team,
      TF2LineParser::Events::BuiltObject => :builtobject,
      TF2LineParser::Events::Airshot => :airshot,
      TF2LineParser::Events::HeadshotDamage => :headshot_damage,
      TF2LineParser::Events::Damage => :damage,
      TF2LineParser::Events::MedicDeath => :medic_death,
      TF2LineParser::Events::MedicDeathEx => :medic_death_ex,
      TF2LineParser::Events::KilledObject => :killedobject,
      TF2LineParser::Events::ShotFired => :shot_fired,
      TF2LineParser::Events::ShotHit => :shot_hit,
      TF2LineParser::Events::Assist => :assist,
      TF2LineParser::Events::PositionReport => :position_report
    }.each do |event_class, expected_type|
      it "maps #{event_class.name.demodulize} to #{expected_type.inspect}" do
        formatter = described_class.new("irrelevant")
        formatter.instance_variable_set(:@parsed_event, event_class.allocate)
        expect(formatter.event_type).to eq(expected_type)
      end
    end

    it "maps a Spawn event to :role_change (Spawn < RoleChange, caught by the earlier branch)" do
      formatter = described_class.new("irrelevant")
      formatter.instance_variable_set(:@parsed_event, TF2LineParser::Events::Spawn.allocate)
      expect(formatter.event_type).to eq(:role_change)
    end

    it "returns :unknown when the line cannot be parsed into an event" do
      expect(described_class.new("not a parseable log line").event_type).to eq(:unknown)
    end
  end

  describe ".steam_id_to_community_id" do
    it "converts Steam ID3 format" do
      expect(described_class.steam_id_to_community_id("[U:1:231702]")).to eq(76561197960497430)
    end

    it "converts STEAM_X format" do
      expect(described_class.steam_id_to_community_id("STEAM_0:0:5253998")).to eq(76561197970773724)
    end

    it "returns nil for Console" do
      expect(described_class.steam_id_to_community_id("Console")).to be_nil
    end

    it "returns nil for BOT" do
      expect(described_class.steam_id_to_community_id("BOT")).to be_nil
    end

    it "returns nil for blank" do
      expect(described_class.steam_id_to_community_id("")).to be_nil
    end
  end

  describe "sensitive data sanitization" do
    it "sanitizes IP addresses in raw output" do
      line = 'L 01/01/2026 - 12:00:00: "Player<2><[U:1:12345]><Red>" connected, address "192.168.1.100:27005"'
      result = described_class.new(line).format
      expect(result[:raw]).to include("0.0.0.0")
      expect(result[:raw]).not_to include("192.168.1.100")
    end

    it "sanitizes rcon_password" do
      line = 'L 01/01/2026 - 12:00:00: rcon from "192.168.1.1:27015": command "rcon_password "secret123""'
      result = described_class.new(line).format
      expect(result[:raw]).to include('rcon_password "*****"')
      expect(result[:raw]).not_to include("secret123")
    end

    it "sanitizes sv_password" do
      line = 'L 01/01/2026 - 12:00:00: rcon: sv_password "mysecret"'
      result = described_class.new(line).format
      expect(result[:raw]).to include('sv_password "*****"')
      expect(result[:raw]).not_to include("mysecret")
    end

    it "sanitizes API keys" do
      line = 'L 01/01/2026 - 12:00:00: rcon: logstf_apikey "abc123def456"'
      result = described_class.new(line).format
      expect(result[:raw]).to include('logstf_apikey "*****"')
      expect(result[:raw]).not_to include("abc123def456")
    end

    it "sanitizes sv_logsecret" do
      line = 'L 01/01/2026 - 12:00:00: rcon: sv_logsecret secretvalue123'
      result = described_class.new(line).format
      expect(result[:raw]).to include('sv_logsecret "*****"')
      expect(result[:raw]).not_to include("secretvalue123")
    end
  end
end
