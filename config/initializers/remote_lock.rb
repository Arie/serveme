$lock = RemoteLock.new(RemoteLock::Adapters::Redis.new(Redis.new))
