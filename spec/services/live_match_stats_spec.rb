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

    it 'sets scores from FinalScore events' do
      described_class.process_line(reservation_id, 'L 03/22/2026 - 20:06:01: Team "Red" final score "3" with "6" players')

      stats = described_class.get_stats(reservation_id).first
      expect(stats[:scores]["Red"]).to eq(3)
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
