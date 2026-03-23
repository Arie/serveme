# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LogParser do
  let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'logs', 'match.log').to_s }

  describe '#perform' do
    context 'with a valid match log' do
      subject(:matches) { described_class.new(fixture_path).perform }

      it 'returns an array of MatchData' do
        expect(matches).to be_an(Array)
        expect(matches.first).to be_a(LogParser::MatchData)
      end

      it 'finds all 12 players' do
        expect(matches.first.players.size).to eq(12)
      end

      it 'assigns players to Red and Blue teams' do
        match_data = matches.first
        red_players = match_data.players.select { |p| p.team == 'Red' }
        blue_players = match_data.players.select { |p| p.team == 'Blue' }
        expect(red_players.size).to eq(6)
        expect(blue_players.size).to eq(6)
      end

      it 'tracks kills correctly' do
        red_scout1 = matches.first.players.find { |p| p.name == 'RedScout1' }
        expect(red_scout1.kills).to eq(1)
      end

      it 'tracks deaths correctly' do
        red_scout1 = matches.first.players.find { |p| p.name == 'RedScout1' }
        expect(red_scout1.deaths).to eq(2)
      end

      it 'tracks damage' do
        red_scout1 = matches.first.players.find { |p| p.name == 'RedScout1' }
        expect(red_scout1.damage).to eq(80)
      end

      it 'tracks healing' do
        red_medic = matches.first.players.find { |p| p.name == 'RedMedic' }
        expect(red_medic.healing).to eq(150)
      end

      it 'tracks ubers' do
        red_medic = matches.first.players.find { |p| p.name == 'RedMedic' }
        expect(red_medic.ubers).to eq(1)
      end

      it 'determines player classes' do
        red_demo = matches.first.players.find { |p| p.name == 'RedDemo' }
        expect(red_demo.tf2_class).to eq('demoman')
      end

      it 'records round wins' do
        expect(matches.first.round_wins['Red']).to eq(1)
        expect(matches.first.round_wins['Blue']).to eq(1)
      end

      it 'records round lengths' do
        expect(matches.first.round_lengths).to eq([ 240.0, 240.0 ])
      end

      it 'calculates total duration' do
        expect(matches.first.total_duration_seconds).to eq(480.0)
      end

      it 'records final scores' do
        expect(matches.first.final_scores['Red']).to eq(3)
        expect(matches.first.final_scores['Blue']).to eq(2)
      end

      it 'marks the match as ended' do
        expect(matches.first.match_ended).to be true
      end
    end

    context 'with a 2-player match' do
      it 'still returns the match' do
        log_content = <<~LOG
          L 03/22/2026 - 20:00:00: Log file started (file "logs/L0322001.log") (game "/home/tf2/tf2-1/orangebox/tf") (version "8601326")
          L 03/22/2026 - 20:01:00: World triggered "Round_Start"
          L 03/22/2026 - 20:01:10: "Player1<3><[U:1:200002]><Red>" killed "Player2<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")
          L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")
          L 03/22/2026 - 20:06:00: World triggered "Round_Length" (seconds "300.00")
          L 03/22/2026 - 20:06:01: Team "Red" final score "1" with "1" players
          L 03/22/2026 - 20:06:01: Team "Blue" final score "0" with "1" players
          L 03/22/2026 - 20:06:02: World triggered "Game_Over" reason "Reached Win Limit"
        LOG

        file = Tempfile.new([ 'log_parser_test', '.log' ])
        file.write(log_content)
        file.close

        result = described_class.new(file.path).perform
        expect(result.size).to eq(1)

        file.unlink
      end
    end

    context 'with a match that did not end' do
      it 'returns empty array' do
        log_content = <<~LOG
          L 03/22/2026 - 20:00:00: Log file started (file "logs/L0322001.log") (game "/home/tf2/tf2-1/orangebox/tf") (version "8601326")
          L 03/22/2026 - 20:01:00: World triggered "Round_Start"
          L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")
          L 03/22/2026 - 20:06:00: World triggered "Round_Length" (seconds "300.00")
        LOG

        file = Tempfile.new([ 'log_parser_test', '.log' ])
        file.write(log_content)
        file.close

        result = described_class.new(file.path).perform
        expect(result).to be_empty

        file.unlink
      end
    end

    context 'with a match too short in duration' do
      it 'returns empty array when total round time is under 300 seconds' do
        lines = [ "L 03/22/2026 - 20:00:00: Log file started (file \"logs/L0322001.log\") (game \"/home/tf2/tf2-1/orangebox/tf\") (version \"8601326\")" ]
        lines << 'L 03/22/2026 - 20:01:00: World triggered "Round_Start"'

        (1..6).each do |i|
          steam = "[U:1:#{600000 + i * 2}]"
          lines << "L 03/22/2026 - 20:00:0#{i}: \"RedPlayer#{i}<#{i + 2}><#{steam}><Red>\" spawned as \"Scout\""
          lines << "L 03/22/2026 - 20:00:0#{i}: \"RedPlayer#{i}<#{i + 2}><#{steam}><Red>\" triggered \"damage\" against \"BluePlayer#{i}<#{i + 8}><[U:1:#{800000 + i * 2}]><Blue>\" (damage \"100\") (weapon \"scattergun\")"
        end
        (1..6).each do |i|
          steam = "[U:1:#{800000 + i * 2}]"
          lines << "L 03/22/2026 - 20:00:0#{i}: \"BluePlayer#{i}<#{i + 8}><#{steam}><Blue>\" spawned as \"Scout\""
          lines << "L 03/22/2026 - 20:00:0#{i}: \"BluePlayer#{i}<#{i + 8}><#{steam}><Blue>\" triggered \"damage\" against \"RedPlayer#{i}<#{i + 2}><[U:1:#{600000 + i * 2}]><Red>\" (damage \"100\") (weapon \"scattergun\")"
        end

        lines << 'L 03/22/2026 - 20:01:00: World triggered "Round_Win" (winner "Red")'
        lines << 'L 03/22/2026 - 20:01:00: World triggered "Round_Length" (seconds "60.00")'
        lines << 'L 03/22/2026 - 20:01:01: Team "Red" final score "1" with "6" players'
        lines << 'L 03/22/2026 - 20:01:01: Team "Blue" final score "0" with "6" players'
        lines << 'L 03/22/2026 - 20:01:02: World triggered "Game_Over" reason "Reached Win Limit"'

        file = Tempfile.new([ 'log_parser_test', '.log' ])
        file.write(lines.join("\n"))
        file.close

        result = described_class.new(file.path).perform
        expect(result).to be_empty

        file.unlink
      end
    end
  end

  describe LogParser::PlayerStats do
    describe '#team' do
      it 'returns the most frequent team' do
        player = described_class.new(
          steam_uid: 123, name: 'Test', team_counts: { 'Red' => 5, 'Blue' => 2 },
          class_counts: Hash.new(0), kills: 0, assists: 0, deaths: 0, damage: 0, damage_taken: 0, healing: 0, heals_received: 0, ubers: 0, drops: 0, airshots: 0, caps: 0
        )
        expect(player.team).to eq('Red')
      end
    end

    describe '#tf2_class' do
      it 'returns the most played class' do
        player = described_class.new(
          steam_uid: 123, name: 'Test', team_counts: Hash.new(0),
          class_counts: { 'scout' => 10, 'soldier' => 3 }, kills: 0, assists: 0, deaths: 0, damage: 0, damage_taken: 0, healing: 0, heals_received: 0, ubers: 0, drops: 0, airshots: 0, caps: 0
        )
        expect(player.tf2_class).to eq('scout')
      end

      it 'returns unknown when no classes recorded' do
        player = described_class.new(
          steam_uid: 123, name: 'Test', team_counts: Hash.new(0),
          class_counts: Hash.new(0), kills: 0, assists: 0, deaths: 0, damage: 0, damage_taken: 0, healing: 0, heals_received: 0, ubers: 0, drops: 0, airshots: 0, caps: 0
        )
        expect(player.tf2_class).to eq('unknown')
      end
    end
  end
end
