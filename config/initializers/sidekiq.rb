# typed: strict
# frozen_string_literal: true

schedule_file = LAN_MODE ? "config/schedule.lan.yml" : "config/schedule.yml"

Sidekiq::Cron::Job.load_from_hash! YAML.load_file(schedule_file) if File.exist?(schedule_file) && Sidekiq.server?

if Rails.env.test?
  # Same per-worker db as $lock, so parallel test workers don't share Sidekiq state
  worker_index = [ ENV.fetch("TEST_ENV_NUMBER", "1").to_i - 1, 0 ].max
  Sidekiq.configure_client { |config| config.redis = { db: ENV.fetch("REDIS_LOCK_DB", 3).to_i + worker_index } }
end
