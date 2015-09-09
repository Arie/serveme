cache = Rails.cache.dalli
if cache.is_a? Dalli::Client
  $lock = RemoteLock.new(RemoteLock::Adapters::Dalli.new(cache))
else
  $lock = RemoteLock.new(RemoteLock::Adapters::DalliConnectionPool.new(cache))
end
