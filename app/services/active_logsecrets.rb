# typed: true
# frozen_string_literal: true

# Publishes the logsecrets of current reservations to Redis. The logdaemon
# only accepts UDP log lines carrying one of these, so random senders can't
# make it write files or enqueue jobs. CronWorker rebuilds the set every
# minute; new reservations are added right away so no startup lines are lost.
class ActiveLogsecrets
  extend T::Sig

  KEY = "active_logsecrets"
  # Keeps the key present when no reservation is active, so the logdaemon can
  # tell "nothing active" apart from "never published" (where it accepts all).
  SENTINEL = "-"
  TTL = 5 * 60
  # Covers cloud servers booting before starts_at and log lines arriving
  # after a reservation ended.
  MARGIN = 10.minutes

  sig { void }
  def self.publish
    now = Time.current
    secrets = Reservation.where(starts_at: ..(now + MARGIN), ends_at: (now - MARGIN)..).where.not(logsecret: nil).pluck(:logsecret)
    tmp_key = "#{KEY}:tmp"

    Sidekiq.redis do |r|
      r.multi do |tx|
        tx.call("DEL", tmp_key)
        tx.call("SADD", tmp_key, SENTINEL, *secrets)
        tx.call("RENAME", tmp_key, KEY)
        tx.call("EXPIRE", KEY, TTL)
      end
    end
  end

  sig { params(logsecret: String).void }
  def self.add(logsecret)
    Sidekiq.redis do |r|
      # Adding to a missing key would make it look like the complete list
      r.call("SADD", KEY, logsecret) if r.call("EXISTS", KEY) > 0
    end
  end
end
