# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe MatchStatsWorker do
  let(:reservation) { create :reservation }
  let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'logs', 'match.log').to_s }
  let(:log_dir) { Rails.root.join('server_logs', reservation.id.to_s) }

  before do
    FileUtils.mkdir_p(log_dir)
    FileUtils.cp(fixture_path, File.join(log_dir, 'match.log'))
  end

  after do
    FileUtils.rm_rf(log_dir)
    LiveMatchStats.clear(reservation.id)
  end

  describe '#perform' do
    it 'creates ReservationMatch records from log files' do
      expect { described_class.new.perform(reservation.id) }
        .to change(ReservationMatch, :count).by(1)
    end

    it 'creates MatchPlayer records for each player' do
      expect { described_class.new.perform(reservation.id) }
        .to change(MatchPlayer, :count).by(12)
    end

    it 'sets correct scores on the match' do
      described_class.new.perform(reservation.id)

      match = ReservationMatch.find_by(reservation_id: reservation.id)
      expect(match.red_score).to eq(3)
      expect(match.blue_score).to eq(2)
    end

    it 'sets correct stats on players' do
      described_class.new.perform(reservation.id)

      match = ReservationMatch.find_by(reservation_id: reservation.id)
      red_scout = match.match_players.find_by(steam_uid: SteamCondenser::Community::SteamId.steam_id_to_community_id('[U:1:200002]'))
      expect(red_scout).to be_present
      expect(red_scout.team).to eq('Red')
      expect(red_scout.kills).to be >= 0
    end

    it 'marks winning team players as won' do
      described_class.new.perform(reservation.id)

      match = ReservationMatch.find_by(reservation_id: reservation.id)
      red_players = match.match_players.where(team: 'Red')
      blue_players = match.match_players.where(team: 'Blue')

      expect(red_players.pluck(:won).uniq).to eq([ true ])
      expect(blue_players.pluck(:won).uniq).to eq([ false ])
    end

    it 'clears live match stats from Redis' do
      LiveMatchStats.rebuild(reservation.id, fixture_path)
      expect(LiveMatchStats.exists?(reservation.id)).to be true

      described_class.new.perform(reservation.id)
      expect(LiveMatchStats.exists?(reservation.id)).to be false
    end

    it 'skips if ReservationMatch already exists' do
      described_class.new.perform(reservation.id)

      expect { described_class.new.perform(reservation.id) }
        .not_to change(ReservationMatch, :count)
    end

    it 'skips if no log files exist' do
      FileUtils.rm_rf(log_dir)

      expect { described_class.new.perform(reservation.id) }
        .not_to change(ReservationMatch, :count)
    end
  end
end
