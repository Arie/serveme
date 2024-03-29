# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `redis-store` gem.
# Please instead update this file by running `bin/tapioca gem redis-store`.

# source://redis-store//lib/redis/store/factory.rb#3
class Redis
  include ::Redis::Commands::Bitmaps
  include ::Redis::Commands::Cluster
  include ::Redis::Commands::Connection
  include ::Redis::Commands::Geo
  include ::Redis::Commands::Hashes
  include ::Redis::Commands::HyperLogLog
  include ::Redis::Commands::Keys
  include ::Redis::Commands::Lists
  include ::Redis::Commands::Pubsub
  include ::Redis::Commands::Scripting
  include ::Redis::Commands::Server
  include ::Redis::Commands::Sets
  include ::Redis::Commands::SortedSets
  include ::Redis::Commands::Streams
  include ::Redis::Commands::Strings
  include ::Redis::Commands::Transactions

  # source://redis/4.8.1/lib/redis.rb#83
  def initialize(options = T.unsafe(nil)); end

  # source://redis/4.8.1/lib/redis.rb#160
  def _client; end

  # source://redis/4.8.1/lib/redis.rb#110
  def close; end

  # source://redis/4.8.1/lib/redis.rb#140
  def commit; end

  # source://redis/4.8.1/lib/redis.rb#105
  def connected?; end

  # source://redis/4.8.1/lib/redis.rb#250
  def connection; end

  # source://redis/4.8.1/lib/redis.rb#110
  def disconnect!; end

  # source://redis/4.8.1/lib/redis.rb#246
  def dup; end

  # source://redis/4.8.1/lib/redis.rb#238
  def id; end

  # source://redis/4.8.1/lib/redis.rb#242
  def inspect; end

  # source://redis/4.8.1/lib/redis.rb#214
  def multi(&block); end

  # source://redis/4.8.1/lib/redis.rb#164
  def pipelined(&block); end

  # source://redis/4.8.1/lib/redis.rb#125
  def queue(*command); end

  # source://redis/4.8.1/lib/redis.rb#115
  def with; end

  # source://redis/4.8.1/lib/redis.rb#93
  def with_reconnect(val = T.unsafe(nil), &blk); end

  # source://redis/4.8.1/lib/redis.rb#100
  def without_reconnect(&blk); end

  private

  # source://redis/4.8.1/lib/redis.rb#280
  def _subscription(method, timeout, channels, block); end

  # source://redis/4.8.1/lib/redis.rb#274
  def send_blocking_command(command, timeout, &block); end

  # source://redis/4.8.1/lib/redis.rb#268
  def send_command(command, &block); end

  # source://redis/4.8.1/lib/redis.rb#264
  def synchronize; end

  class << self
    # source://redis/4.8.1/lib/redis.rb#40
    def current; end

    # source://redis/4.8.1/lib/redis.rb#45
    def current=(redis); end

    # source://redis/4.8.1/lib/redis.rb#30
    def deprecate!(message); end

    # source://redis/4.8.1/lib/redis.rb#15
    def exists_returns_integer; end

    # source://redis/4.8.1/lib/redis.rb#18
    def exists_returns_integer=(value); end

    # source://redis/4.8.1/lib/redis.rb#16
    def raise_deprecations; end

    # source://redis/4.8.1/lib/redis.rb#16
    def raise_deprecations=(_arg0); end

    # source://redis/4.8.1/lib/redis.rb#16
    def sadd_returns_boolean; end

    # source://redis/4.8.1/lib/redis.rb#16
    def sadd_returns_boolean=(_arg0); end

    # source://redis/4.8.1/lib/redis.rb#16
    def silence_deprecations; end

    # source://redis/4.8.1/lib/redis.rb#16
    def silence_deprecations=(_arg0); end
  end
end

# source://redis/4.8.1/lib/redis.rb#8
Redis::BASE_PATH = T.let(T.unsafe(nil), String)

# source://redis-store//lib/redis/distributed_store.rb#4
class Redis::DistributedStore < ::Redis::Distributed
  # @return [DistributedStore] a new instance of DistributedStore
  #
  # source://redis-store//lib/redis/distributed_store.rb#8
  def initialize(addresses, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/distributed_store.rb#29
  def get(key, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/distributed_store.rb#17
  def nodes; end

  # source://redis-store//lib/redis/distributed_store.rb#21
  def reconnect; end

  # source://redis-store//lib/redis/distributed_store.rb#37
  def redis_version; end

  # Returns the value of attribute ring.
  #
  # source://redis-store//lib/redis/distributed_store.rb#6
  def ring; end

  # source://redis-store//lib/redis/distributed_store.rb#25
  def set(key, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/distributed_store.rb#49
  def setex(key, expiry, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/distributed_store.rb#33
  def setnx(key, value, options = T.unsafe(nil)); end

  # @return [Boolean]
  #
  # source://redis-store//lib/redis/distributed_store.rb#41
  def supports_redis_version?(version); end

  private

  # source://redis-store//lib/redis/distributed_store.rb#54
  def _extend_namespace(options); end

  # source://redis-store//lib/redis/distributed_store.rb#59
  def _merge_options(address, options); end
end

# source://redis-store//lib/redis/store/factory.rb#4
class Redis::Store < ::Redis
  include ::Redis::Store::RedisVersion
  include ::Redis::Store::Interface
  include ::Redis::Store::Ttl

  # @return [Store] a new instance of Store
  #
  # source://redis-store//lib/redis/store.rb#16
  def initialize(options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store.rb#48
  def location; end

  # source://redis-store//lib/redis/store.rb#40
  def reconnect; end

  # source://redis-store//lib/redis/store.rb#44
  def to_s; end

  private

  # source://redis-store//lib/redis/store.rb#59
  def _extend_marshalling(options); end

  # source://redis-store//lib/redis/store.rb#63
  def _extend_namespace(options); end
end

# source://redis-store//lib/redis/store/factory.rb#5
class Redis::Store::Factory
  # @return [Factory] a new instance of Factory
  #
  # source://redis-store//lib/redis/store/factory.rb#12
  def initialize(*options); end

  # source://redis-store//lib/redis/store/factory.rb#18
  def create; end

  private

  # source://redis-store//lib/redis/store/factory.rb#98
  def extract_addresses_and_options(*options); end

  class << self
    # source://redis-store//lib/redis/store/factory.rb#8
    def create(*options); end

    # source://redis-store//lib/redis/store/factory.rb#38
    def extract_host_options_from_hash(options); end

    # source://redis-store//lib/redis/store/factory.rb#67
    def extract_host_options_from_uri(uri); end

    # @return [Boolean]
    #
    # source://redis-store//lib/redis/store/factory.rb#63
    def host_options?(options); end

    # source://redis-store//lib/redis/store/factory.rb#47
    def normalize_key_names(options); end

    # :api: private
    #
    # source://redis-store//lib/redis/store/factory.rb#30
    def resolve(uri); end
  end
end

# source://redis-store//lib/redis/store/factory.rb#6
Redis::Store::Factory::DEFAULT_PORT = T.let(T.unsafe(nil), Integer)

# source://redis-store//lib/redis/store/interface.rb#3
module Redis::Store::Interface
  # source://redis-store//lib/redis/store/interface.rb#4
  def get(key, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/interface.rb#11
  def set(key, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/interface.rb#24
  def setex(key, expiry, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/interface.rb#20
  def setnx(key, value, options = T.unsafe(nil)); end
end

# source://redis-store//lib/redis/store/interface.rb#8
Redis::Store::Interface::REDIS_SET_OPTIONS = T.let(T.unsafe(nil), Array)

# source://redis-store//lib/redis/store/namespace.rb#3
module Redis::Store::Namespace
  # source://redis-store//lib/redis/store/namespace.rb#38
  def decrby(key, increment); end

  # source://redis-store//lib/redis/store/namespace.rb#57
  def del(*keys); end

  # source://redis-store//lib/redis/store/namespace.rb#26
  def exists(*keys); end

  # @return [Boolean]
  #
  # source://redis-store//lib/redis/store/namespace.rb#30
  def exists?(*keys); end

  # source://redis-store//lib/redis/store/namespace.rb#81
  def expire(key, ttl); end

  # source://redis-store//lib/redis/store/namespace.rb#173
  def flushdb; end

  # source://redis-store//lib/redis/store/namespace.rb#22
  def get(key, *args); end

  # source://redis-store//lib/redis/store/namespace.rb#85
  def hdel(key, *fields); end

  # source://redis-store//lib/redis/store/namespace.rb#97
  def hexists(key, field); end

  # source://redis-store//lib/redis/store/namespace.rb#89
  def hget(key, field); end

  # source://redis-store//lib/redis/store/namespace.rb#93
  def hgetall(key); end

  # source://redis-store//lib/redis/store/namespace.rb#101
  def hincrby(key, field, increment); end

  # source://redis-store//lib/redis/store/namespace.rb#105
  def hincrbyfloat(key, field, increment); end

  # source://redis-store//lib/redis/store/namespace.rb#109
  def hkeys(key); end

  # source://redis-store//lib/redis/store/namespace.rb#113
  def hlen(key); end

  # source://redis-store//lib/redis/store/namespace.rb#117
  def hmget(key, *fields, &blk); end

  # source://redis-store//lib/redis/store/namespace.rb#121
  def hmset(key, *attrs); end

  # source://redis-store//lib/redis/store/namespace.rb#137
  def hscan(key, *args, **_arg2); end

  # source://redis-store//lib/redis/store/namespace.rb#141
  def hscan_each(key, *args, **_arg2); end

  # source://redis-store//lib/redis/store/namespace.rb#125
  def hset(key, *args); end

  # source://redis-store//lib/redis/store/namespace.rb#129
  def hsetnx(key, field, val); end

  # source://redis-store//lib/redis/store/namespace.rb#133
  def hvals(key); end

  # source://redis-store//lib/redis/store/namespace.rb#34
  def incrby(key, increment); end

  # source://redis-store//lib/redis/store/namespace.rb#42
  def keys(pattern = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/namespace.rb#69
  def mget(*keys, &blk); end

  # source://redis-store//lib/redis/store/namespace.rb#46
  def scan(cursor, match: T.unsafe(nil), **kwargs); end

  # source://redis-store//lib/redis/store/namespace.rb#6
  def set(key, *args, **_arg2); end

  # source://redis-store//lib/redis/store/namespace.rb#10
  def setex(key, *args, **_arg2); end

  # source://redis-store//lib/redis/store/namespace.rb#14
  def setnx(key, *args, **_arg2); end

  # source://redis-store//lib/redis/store/namespace.rb#165
  def to_s; end

  # source://redis-store//lib/redis/store/namespace.rb#18
  def ttl(key, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/namespace.rb#61
  def unlink(*keys); end

  # source://redis-store//lib/redis/store/namespace.rb#65
  def watch(*keys); end

  # source://redis-store//lib/redis/store/namespace.rb#178
  def with_namespace(ns); end

  # source://redis-store//lib/redis/store/namespace.rb#153
  def zadd(key, *args); end

  # source://redis-store//lib/redis/store/namespace.rb#145
  def zincrby(key, increment, member); end

  # source://redis-store//lib/redis/store/namespace.rb#157
  def zrem(key, member); end

  # source://redis-store//lib/redis/store/namespace.rb#149
  def zscore(key, member); end

  private

  # source://redis-store//lib/redis/store/namespace.rb#195
  def interpolate(key); end

  # @yield [interpolate(key)]
  #
  # source://redis-store//lib/redis/store/namespace.rb#187
  def namespace(key); end

  # source://redis-store//lib/redis/store/namespace.rb#205
  def namespace_regexp; end

  # source://redis-store//lib/redis/store/namespace.rb#191
  def namespace_str; end

  # source://redis-store//lib/redis/store/namespace.rb#200
  def strip_namespace(key); end
end

# source://redis-store//lib/redis/store/namespace.rb#4
Redis::Store::Namespace::FLUSHDB_BATCH_SIZE = T.let(T.unsafe(nil), Integer)

# source://redis-store//lib/redis/store/redis_version.rb#3
module Redis::Store::RedisVersion
  # source://redis-store//lib/redis/store/redis_version.rb#4
  def redis_version; end

  # @return [Boolean]
  #
  # source://redis-store//lib/redis/store/redis_version.rb#8
  def supports_redis_version?(version); end
end

# source://redis-store//lib/redis/store/serialization.rb#3
module Redis::Store::Serialization
  # source://redis-store//lib/redis/store/serialization.rb#16
  def get(key, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/serialization.rb#20
  def mget(*keys, &blk); end

  # source://redis-store//lib/redis/store/serialization.rb#28
  def mset(*args); end

  # source://redis-store//lib/redis/store/serialization.rb#4
  def set(key, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/serialization.rb#12
  def setex(key, expiry, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/serialization.rb#8
  def setnx(key, value, options = T.unsafe(nil)); end

  private

  # @yield [marshal?(options) ? @serializer.dump(val) : val]
  #
  # source://redis-store//lib/redis/store/serialization.rb#39
  def _marshal(val, options); end

  # source://redis-store//lib/redis/store/serialization.rb#43
  def _unmarshal(val, options); end

  # source://redis-store//lib/redis/store/serialization.rb#56
  def encode(string); end

  # @return [Boolean]
  #
  # source://redis-store//lib/redis/store/serialization.rb#47
  def marshal?(options); end

  # @return [Boolean]
  #
  # source://redis-store//lib/redis/store/serialization.rb#51
  def unmarshal?(result, options); end
end

# source://redis-store//lib/redis/store/ttl.rb#3
module Redis::Store::Ttl
  # source://redis-store//lib/redis/store/ttl.rb#4
  def set(key, value, options = T.unsafe(nil)); end

  # source://redis-store//lib/redis/store/ttl.rb#12
  def setnx(key, value, options = T.unsafe(nil)); end

  protected

  # source://redis-store//lib/redis/store/ttl.rb#21
  def setnx_with_expire(key, value, ttl, options = T.unsafe(nil)); end

  private

  # source://redis-store//lib/redis/store/ttl.rb#34
  def expires_in(options); end

  # source://redis-store//lib/redis/store/ttl.rb#41
  def with_multi_or_pipelined(options, &block); end
end

# source://redis-store//lib/redis/store/version.rb#3
Redis::Store::VERSION = T.let(T.unsafe(nil), String)

# source://redis/4.8.1/lib/redis/version.rb#4
Redis::VERSION = T.let(T.unsafe(nil), String)
