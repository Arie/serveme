# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LogBatchWorker do
  let(:user)        { create :user, uid: '76561197960497430' }
  let(:server)      { double(:server, id: 1, rcon_auth: true, condenser: condenser, supports_mitigations?: false, provision_estimate: nil, end_estimate: nil).as_null_object }
  let(:condenser)   { double.as_null_object }
  let(:reservation) { create :reservation, user: user, logsecret: '7654321' }

  let(:say_line)       { '7654321L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "hello"' }
  let(:kill_line)      { '7654321L 03/29/2014 - 13:15:54: "Attacker<3><[U:1:200002]><Red>" killed "Victim<4><[U:1:400002]><Blue>" with "scattergun" (attacker_position "0 0 0") (victim_position "0 0 0")' }
  let(:connect_line)   { '7654321L 03/29/2014 - 13:15:53: "Normal<3><[U:1:12345]><>" connected, address "1.128.0.1:1234"' }
  let(:mapstart_line)  { '7654321L 02/07/2015 - 20:39:40: Started map "cp_badlands" (CRC "a7e226a1ff6dd4b8d546d7d341d446dc")' }
  let(:end_line)       { '7654321L 03/29/2014 - 13:15:53: "Arie - serveme.tf<3><[U:1:231702]><Red>" say "!end"' }
  let(:other_secret_line) { '9999999L 03/29/2014 - 13:15:53: "Player<3><[U:1:12345]><Red>" say "test"' }

  before do
    allow(Server).to receive(:find).with(anything).and_return(server)
    Rails.cache.clear
    allow(Reservation).to receive(:current).and_return(Reservation)
    allow(Reservation).to receive(:includes).with(:user).and_return(Reservation)
    allow(Reservation).to receive(:find_by_id).with(reservation.id).and_return(reservation)
    allow(reservation).to receive(:server).and_return(server)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_remove)
    allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    allow(TurboSubscriberChecker).to receive(:has_subscribers?).and_return(false)
    allow(TurboSubscriberChecker).to receive(:has_model_subscribers?).and_return(false)
  end

  describe '#perform' do
    it 'returns early with empty log_lines array' do
      expect(LogWorker).not_to receive(:new)
      LogBatchWorker.new.perform([])
    end

    it 'processes each line independently without state leakage' do
      # A mapstart line followed by a say line should produce distinct status updates for each
      LogBatchWorker.new.perform([ mapstart_line, say_line ])

      statuses = ReservationStatus.where(reservation_id: reservation.id).pluck(:status)
      expect(statuses).to include(a_string_matching(/cp_badlands/))
    end

    it 'handles lines with unknown logsecrets' do
      expect { LogBatchWorker.new.perform([ '0000000L some garbage line' ]) }.not_to raise_error
    end

    it 'creates status updates from log events' do
      LogBatchWorker.new.perform([ mapstart_line ])

      statuses = ReservationStatus.where(reservation_id: reservation.id).pluck(:status)
      expect(statuses).to include(a_string_matching(/cp_badlands/))
    end
  end

  describe 'broadcasting' do
    it 'broadcasts to user stream when subscribers are present' do
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).with("reservation_7654321_log_lines").and_return(true)
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).with("reservation_7654321_log_lines_admin").and_return(false)

      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        "reservation_7654321_log_lines",
        hash_including(target: "reservation_7654321_log_lines")
      )

      LogBatchWorker.new.perform([ say_line ])
    end

    it 'broadcasts to admin stream when admin subscribers are present' do
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).with("reservation_7654321_log_lines").and_return(false)
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).with("reservation_7654321_log_lines_admin").and_return(true)

      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        "reservation_7654321_log_lines_admin",
        hash_including(target: "reservation_7654321_log_lines")
      )

      LogBatchWorker.new.perform([ say_line ])
    end

    it 'does not broadcast when no subscribers are present' do
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).and_return(false)

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_prepend_to)
      LogBatchWorker.new.perform([ say_line ])
    end

    it 'groups lines by logsecret for batched broadcasts' do
      user2 = create :user, uid: '76561197960497431'
      reservation2 = create :reservation, user: user2, logsecret: '9999999'
      allow(Reservation).to receive(:find_by_id).with(reservation2.id).and_return(reservation2)
      allow(reservation2).to receive(:server).and_return(server)

      allow(TurboSubscriberChecker).to receive(:has_subscribers?).and_return(true)

      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        "reservation_7654321_log_lines",
        hash_including(target: "reservation_7654321_log_lines")
      )
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        "reservation_7654321_log_lines_admin",
        hash_including(target: "reservation_7654321_log_lines")
      )
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        "reservation_9999999_log_lines",
        hash_including(target: "reservation_9999999_log_lines")
      )
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        "reservation_9999999_log_lines_admin",
        hash_including(target: "reservation_9999999_log_lines")
      )

      LogBatchWorker.new.perform([ say_line, other_secret_line ])
    end
  end

  describe 'log_listeners' do
    it 'sets log_listeners in Redis when subscribers are active' do
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).and_return(true)

      LogBatchWorker.new.perform([ say_line ])

      listener_value = Sidekiq.redis { |r| r.get("log_listeners:7654321") }
      expect(listener_value).to eq("1")
    end

    it 'does not set log_listeners when no subscribers are active' do
      allow(TurboSubscriberChecker).to receive(:has_subscribers?).and_return(false)
      allow(TurboSubscriberChecker).to receive(:has_model_subscribers?).and_return(false)

      Sidekiq.redis { |r| r.del("log_listeners:7654321") }

      LogBatchWorker.new.perform([ say_line ])

      listener_value = Sidekiq.redis { |r| r.get("log_listeners:7654321") }
      expect(listener_value).to be_nil
    end
  end

  describe 'scoreboard broadcasts' do
    it 'broadcasts scoreboard when subscribers exist' do
      allow(TurboSubscriberChecker).to receive(:has_model_subscribers?).and_return(true)
      allow(LiveMatchStats).to receive(:get_stats).with(reservation.id).and_return(
        { players: [ { name: 'Test', kills: 1, steam_uid: 123 } ], scores: {} }
      )
      allow(ScoreboardConnectionInfo).to receive(:for_reservation).and_return({})
      allow(ApplicationController).to receive(:render).and_return('<div>scoreboard</div>')

      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
        reservation,
        hash_including(target: "match-scoreboard-#{reservation.id}")
      )

      LogBatchWorker.new.perform([ say_line ])
    end
  end

  describe 'live match stats' do
    it 'updates live match stats from log lines' do
      round_start_line = '7654321L 03/22/2026 - 20:01:00: World triggered "Round_Start"'

      LogBatchWorker.new.perform([ round_start_line, kill_line ])

      all_stats = LiveMatchStats.get_stats(reservation.id)
      expect(all_stats).not_to be_nil
      expect(all_stats.length).to eq(1)
      attacker = all_stats.first[:players].find { |p| p[:name] == 'Attacker' }
      expect(attacker[:kills]).to eq(1)
    end
  end
end
