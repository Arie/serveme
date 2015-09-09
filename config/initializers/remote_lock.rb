$lock = RemoteLock.new(RemoteLock::Adapters::Memcached.new(Rails.cache.dalli))

module RemoteLock::Adapters
  class Memcached < Base

    def store(key, expires_in_seconds)
      @connection.add(key, uid, expires_in_seconds)
    end
  end
end
