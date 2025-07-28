# typed: strict
# frozen_string_literal: true

$lock = RemoteLock.new(RemoteLock::Adapters::Redis.new(Redis.new(db: ENV.fetch("REDIS_LOCK_DB", 3).to_i)))
