# frozen_string_literal: true

$lock = RemoteLock.new(RemoteLock::Adapters::Redis.new(Redis.new(db: 3)))
