# typed: strict
# frozen_string_literal: true

test_env_number = ENV.fetch("TEST_ENV_NUMBER", "")
worker_index = test_env_number.empty? ? 0 : test_env_number.to_i - 1
$lock = RemoteLock.new(RemoteLock::Adapters::Redis.new(Redis.new(db: ENV.fetch("REDIS_LOCK_DB", 3).to_i + worker_index)))
