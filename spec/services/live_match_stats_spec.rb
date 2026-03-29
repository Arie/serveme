# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LiveMatchStats do
  let(:reservation_id) { 99999 }
  let(:round_start) { 'L 03/22/2026 - 20:01:00: World triggered "Round_Start"' }

  before do
    described_class.clear(reservation_id)
  end

  after do
    described_class.clear(reservation_id)
  end

  describe '.process_line' do
    it 'tracks kills and deaths' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")')

      stats = described_class.get_stats(reservation_id).first
      attacker = stats[:players].find { |p| p[:name] == 'Attacker' }
      victim = stats[:players].find { |p| p[:name] == 'Victim' }

      expect(attacker[:kills]).to eq(1)
      expect(victim[:deaths]).to eq(1)
    end

    it 'tracks damage' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" triggered "damage" against "Victim<4><[U:1:400002]><Blue>" (damage "150") (weapon "scattergun")')

      stats = described_class.get_stats(reservation_id).first
      attacker = stats[:players].find { |p| p[:name] == 'Attacker' }
      victim = stats[:players].find { |p| p[:name] == 'Victim' }

      expect(attacker[:damage]).to eq(150)
      expect(victim[:damage_taken]).to eq(150)
    end

    it 'tracks healing' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "Medic<3><[U:1:200002]><Red>" triggered "healed" against "Patient<4><[U:1:400002]><Red>" (healing "75")')

      stats = described_class.get_stats(reservation_id).first
      medic = stats[:players].find { |p| p[:name] == 'Medic' }
      patient = stats[:players].find { |p| p[:name] == 'Patient' }

      expect(medic[:healing]).to eq(75)
      expect(patient[:heals_received]).to eq(75)
    end

    it 'tracks team scores on round win' do
      lines = [
        'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")',
        'L 03/22/2026 - 20:06:01: World triggered "Round_Start"',
        'L 03/22/2026 - 20:11:00: World triggered "Round_Win" (winner "Blue")'
      ]
      lines.each { |line| described_class.process_line(reservation_id, line) }

      stats = described_class.get_stats(reservation_id).first
      expect(stats[:scores]["Red"]).to eq(1)
      expect(stats[:scores]["Blue"]).to eq(1)
    end

    it 'sets scores from FinalScore events during a match' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")')
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")')
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:06:01: Team "Red" final score "3" with "6" players')

      stats = described_class.get_stats(reservation_id).first
      expect(stats[:scores]["Red"]).to eq(3)
    end

    it 'does not create phantom match from FinalScore after MatchEnd' do
      lines = [
        'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
        'L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")',
        'L 03/22/2026 - 20:06:00: Team "Red" current score "1" with "6" players',
        'L 03/22/2026 - 20:06:00: Team "Blue" current score "0" with "6" players',
        'L 03/22/2026 - 20:06:01: World triggered "Game_Over" reason "Reached Win Limit"',
        'L 03/22/2026 - 20:06:01: Team "Red" final score "1" with "6" players',
        'L 03/22/2026 - 20:06:01: Team "Blue" final score "0" with "6" players'
      ]
      lines.each { |line| described_class.process_line(reservation_id, line) }

      all_stats = described_class.get_stats(reservation_id)
      expect(all_stats.size).to eq(1)
      expect(all_stats.first[:scores]["Red"]).to eq(1)
      expect(all_stats.first[:players].size).to eq(2)
    end

    it 'tracks class from spawn events' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:05: "Scout<3><[U:1:200002]><Red>" spawned as "Scout"')

      stats = described_class.get_stats(reservation_id).first
      player = stats[:players].find { |p| p[:name] == 'Scout' }
      expect(player[:tf2_class]).to eq('scout')
    end

    it 'ignores events between rounds' do
      lines = [
        'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
        'L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")',
        'L 03/22/2026 - 20:06:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")'
      ]
      lines.each { |line| described_class.process_line(reservation_id, line) }

      stats = described_class.get_stats(reservation_id).first
      attacker = stats[:players].find { |p| p[:name] == 'Attacker' }
      expect(attacker[:kills]).to eq(1)
    end

    it 'ignores events before first round starts (warmup)' do
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:00:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")')

      stats = described_class.get_stats(reservation_id)
      expect(stats).to be_nil
    end

    it 'resumes tracking after next round starts' do
      lines = [
        'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")',
        'L 03/22/2026 - 20:07:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:07:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")'
      ]
      lines.each { |line| described_class.process_line(reservation_id, line) }

      stats = described_class.get_stats(reservation_id).first
      attacker = stats[:players].find { |p| p[:name] == 'Attacker' }
      expect(attacker[:kills]).to eq(1)
    end

    it 'tracks suicide as death' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "Player<3><[U:1:200002]><Red>" committed suicide with "world" (attacker_position "0 0 0")')

      stats = described_class.get_stats(reservation_id).first
      player = stats[:players].find { |p| p[:name] == 'Player' }
      expect(player[:deaths]).to eq(1)
    end
  end

  describe '.get_stats' do
    it 'returns nil when no data exists' do
      expect(described_class.get_stats(reservation_id)).to be_nil
    end

    it 'returns players grouped with their stats' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "RedScout<3><[U:1:200002]><Red>" killed "BlueSoldier<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")')

      all_stats = described_class.get_stats(reservation_id)
      expect(all_stats.size).to eq(1)
      stats = all_stats.first
      expect(stats[:players].size).to eq(2)
      expect(stats[:players].map { |p| p[:team] }).to contain_exactly('Red', 'Blue')
    end

    it 'splits stats into separate matches on MatchEnd' do
      lines = [
        # First match
        'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
        'L 03/22/2026 - 20:06:00: World triggered "Round_Win" (winner "Red")',
        'L 03/22/2026 - 20:06:01: World triggered "Game_Over" reason "Reached Win Limit"',
        # Second match
        'L 03/22/2026 - 20:08:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:08:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
        'L 03/22/2026 - 20:08:11: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
        'L 03/22/2026 - 20:13:00: World triggered "Round_Win" (winner "Blue")'
      ]
      lines.each { |line| described_class.process_line(reservation_id, line) }

      all_stats = described_class.get_stats(reservation_id)
      expect(all_stats.size).to eq(2)

      first_match = all_stats.first
      attacker_m1 = first_match[:players].find { |p| p[:name] == 'Attacker' }
      expect(attacker_m1[:kills]).to eq(1)
      expect(first_match[:scores]["Red"]).to eq(1)

      second_match = all_stats.last
      attacker_m2 = second_match[:players].find { |p| p[:name] == 'Attacker' }
      expect(attacker_m2[:kills]).to eq(2)
      expect(second_match[:scores]["Blue"]).to eq(1)
    end
  end

  describe '.rebuild' do
    let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'logs', 'match.log').to_s }

    it 'rebuilds stats from a log file' do
      described_class.rebuild(reservation_id, fixture_path)

      all_stats = described_class.get_stats(reservation_id)
      expect(all_stats).not_to be_empty
      total_players = all_stats.sum { |s| s[:players].size }
      expect(total_players).to eq(12)
    end

    it 'clears existing stats before rebuilding' do
      described_class.process_line(reservation_id, round_start)
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:01:10: "OldPlayer<3><[U:1:1999998]><Red>" killed "OldVictim<4><[U:1:1777776]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")')

      described_class.rebuild(reservation_id, fixture_path)

      all_stats = described_class.get_stats(reservation_id)
      all_players = all_stats.flat_map { |s| s[:players] }
      old_player = all_players.find { |p| p[:name] == 'OldPlayer' }
      expect(old_player).to be_nil
    end

    context 'EU pattern: Game_Over followed by FinalScore (EU 1538196)' do
      let(:eu_fixture_path) { Rails.root.join('spec', 'fixtures', 'logs', 'eu_pattern.log').to_s }

      it 'produces exactly one match with no phantom scoreboard' do
        described_class.rebuild(reservation_id, eu_fixture_path)

        all_stats = described_class.get_stats(reservation_id)
        expect(all_stats.size).to eq(1)
      end

      it 'includes players in the completed match' do
        described_class.rebuild(reservation_id, eu_fixture_path)

        all_stats = described_class.get_stats(reservation_id)
        match = all_stats.first
        expect(match[:players].size).to eq(2)
        expect(match[:players].map { |p| p[:team] }).to contain_exactly('Red', 'Blue')
      end

      it 'has correct scores from FinalScore' do
        described_class.rebuild(reservation_id, eu_fixture_path)

        all_stats = described_class.get_stats(reservation_id)
        match = all_stats.first
        expect(match[:scores]["Red"]).to eq(1)
        expect(match[:scores]["Blue"]).to eq(0)
      end

      it 'has correct kill stats' do
        described_class.rebuild(reservation_id, eu_fixture_path)

        all_stats = described_class.get_stats(reservation_id)
        match = all_stats.first
        red_scout = match[:players].find { |p| p[:team] == 'Red' }
        expect(red_scout[:kills]).to eq(1)
        expect(red_scout[:damage]).to eq(100)
      end
    end

    context 'NA pattern: multiple matches rebuilt from log (NA 615734)' do
      let(:multi_match_path) { Rails.root.join('spec', 'fixtures', 'logs', 'multi_match.log').to_s }

      it 'produces two completed matches' do
        described_class.rebuild(reservation_id, multi_match_path)

        all_stats = described_class.get_stats(reservation_id)
        expect(all_stats.size).to eq(2)
      end

      it 'has players in both matches' do
        described_class.rebuild(reservation_id, multi_match_path)

        all_stats = described_class.get_stats(reservation_id)
        all_stats.each_with_index do |match, i|
          expect(match[:players].size).to be >= 4, "Match #{i + 1} should have players but had #{match[:players].size}"
        end
      end

      it 'has correct scores for first match (Red wins 2-0)' do
        described_class.rebuild(reservation_id, multi_match_path)

        first_match = described_class.get_stats(reservation_id).first
        expect(first_match[:scores]["Red"]).to eq(2)
        expect(first_match[:scores]["Blue"]).to eq(0)
      end

      it 'has correct scores for second match (Blue wins 2-0)' do
        described_class.rebuild(reservation_id, multi_match_path)

        second_match = described_class.get_stats(reservation_id).last
        expect(second_match[:scores]["Blue"]).to eq(2)
        expect(second_match[:scores]["Red"]).to eq(0)
      end

      it 'tracks kills correctly across matches' do
        described_class.rebuild(reservation_id, multi_match_path)

        all_stats = described_class.get_stats(reservation_id)

        # First match: RedScout1 gets 2 kills, BlueSoldier1 gets 1 kill
        first_match = all_stats.first
        red_scout_m1 = first_match[:players].find { |p| p[:name] == 'RedScout1' }
        expect(red_scout_m1[:kills]).to eq(2)

        blue_soldier_m1 = first_match[:players].find { |p| p[:name] == 'BlueSoldier1' }
        expect(blue_soldier_m1[:kills]).to eq(1)

        # Second match: BlueScout1 gets 2 kills
        second_match = all_stats.last
        blue_scout_m2 = second_match[:players].find { |p| p[:name] == 'BlueScout1' }
        expect(blue_scout_m2[:kills]).to eq(2)
      end

      it 'tracks healing correctly per match' do
        described_class.rebuild(reservation_id, multi_match_path)

        all_stats = described_class.get_stats(reservation_id)

        first_match = all_stats.first
        red_medic = first_match[:players].find { |p| p[:name] == 'RedMedic' }
        expect(red_medic[:healing]).to eq(200)

        second_match = all_stats.last
        blue_medic = second_match[:players].find { |p| p[:name] == 'BlueMedic' }
        expect(blue_medic[:healing]).to eq(180)
      end
    end
  end

  describe 'verifying old code was broken' do
    context 'EU pattern: FinalScore after Game_Over without the fix creates phantom match' do
      it 'would create a phantom match if FinalScore were not skipped after MatchEnd' do
        lines = [
          'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
          'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
          'L 03/22/2026 - 20:05:00: World triggered "Round_Win" (winner "Red")',
          'L 03/22/2026 - 20:05:00: Team "Red" current score "1" with "6" players',
          'L 03/22/2026 - 20:05:01: World triggered "Game_Over" reason "Reached Win Limit"'
        ]
        lines.each { |line| described_class.process_line(reservation_id, line) }

        # After Game_Over, match is finalized. Now simulate the OLD behavior:
        # write FinalScore directly to Redis bypassing the between_matches check
        key = "live_match:#{reservation_id}"
        Sidekiq.redis do |r|
          r.hset(key, "score:Red", "1")
          r.hset(key, "score:Blue", "0")
        end

        all_stats = described_class.get_stats(reservation_id)
        # This produces 2 entries: the real completed match + a phantom with scores but no players
        expect(all_stats.size).to eq(2)
        phantom = all_stats.last
        expect(phantom[:players]).to be_empty
        expect(phantom[:scores]).to have_key("Red")
      end
    end

    context 'NA pattern: only actionable lines processed without rebuild' do
      it 'produces a match with scores but no players when only round events are received' do
        # Simulate what happens when nobody is watching: only actionable lines reach LiveMatchStats
        # (Round_Start, Round_Win, Round_Length, Game_Over, FinalScore - but NOT kills/spawns/damage)
        actionable_lines = [
          'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
          'L 03/22/2026 - 20:05:00: World triggered "Round_Win" (winner "Red")',
          'L 03/22/2026 - 20:05:00: World triggered "Round_Length" (seconds "240.00")',
          'L 03/22/2026 - 20:05:01: World triggered "Round_Start"',
          'L 03/22/2026 - 20:09:00: World triggered "Round_Win" (winner "Red")',
          'L 03/22/2026 - 20:09:00: World triggered "Round_Length" (seconds "240.00")',
          'L 03/22/2026 - 20:09:01: Team "Red" final score "2" with "4" players',
          'L 03/22/2026 - 20:09:01: Team "Blue" final score "0" with "4" players',
          'L 03/22/2026 - 20:09:02: World triggered "Game_Over" reason "Reached Win Limit"'
        ]
        actionable_lines.each { |line| described_class.process_line(reservation_id, line) }

        all_stats = described_class.get_stats(reservation_id)
        expect(all_stats.size).to eq(1)
        # The match has scores but NO players - this is the NA 615734 bug
        match = all_stats.first
        expect(match[:scores]["Red"]).to eq(2)
        expect(match[:players]).to be_empty
      end
    end
  end

  describe '.clear' do
    it 'removes all stats for a reservation' do
      described_class.process_line(reservation_id, round_start)
      expect(described_class.exists?(reservation_id)).to be true

      described_class.clear(reservation_id)
      expect(described_class.exists?(reservation_id)).to be false
    end

    it 'removes completed match data too' do
      lines = [
        'L 03/22/2026 - 20:01:00: World triggered "Round_Start"',
        'L 03/22/2026 - 20:01:10: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")',
        'L 03/22/2026 - 20:06:01: World triggered "Game_Over" reason "Reached Win Limit"'
      ]
      lines.each { |line| described_class.process_line(reservation_id, line) }

      described_class.clear(reservation_id)
      expect(described_class.get_stats(reservation_id)).to be_nil
    end
  end

  describe '.exists?' do
    it 'returns false when no data exists' do
      expect(described_class.exists?(reservation_id)).to be false
    end

    it 'returns true when data exists' do
      described_class.process_line(reservation_id, round_start)
      expect(described_class.exists?(reservation_id)).to be true
    end
  end
end
