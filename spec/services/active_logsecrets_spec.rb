# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ActiveLogsecrets do
  define_method(:members) do
    Sidekiq.redis { |r| r.call('SMEMBERS', described_class::KEY) }
  end

  before { Sidekiq.redis { |r| r.call('DEL', described_class::KEY) } }
  after { Sidekiq.redis { |r| r.call('DEL', described_class::KEY) } }

  describe '.publish' do
    it 'lists current and nearly starting reservations, but not old or far future ones' do
      current = create(:reservation)
      soon = create(:reservation, starts_at: 5.minutes.from_now, ends_at: 1.hour.from_now)
      ended = create(:reservation)
      ended.update_columns(starts_at: 3.hours.ago, ends_at: 2.hours.ago)
      later = create(:reservation)
      later.update_columns(starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour)

      described_class.publish

      expect(members).to include(current.logsecret, soon.logsecret)
      expect(members).not_to include(ended.logsecret, later.logsecret)
    end

    it 'keeps the key present with a sentinel when nothing is active' do
      described_class.publish

      expect(members).to eq([ described_class::SENTINEL ])
      expect(Sidekiq.redis { |r| r.call('TTL', described_class::KEY) }).to be > 0
    end
  end

  describe '.add' do
    it 'adds a new reservation to a published list' do
      described_class.publish
      reservation = create(:reservation)

      expect(members).to include(reservation.logsecret)
    end

    it "doesn't create the list on its own, so the logdaemon keeps failing open" do
      create(:reservation)

      expect(members).to be_empty
    end
  end
end
