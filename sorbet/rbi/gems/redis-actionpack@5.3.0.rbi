# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `redis-actionpack` gem.
# Please instead update this file by running `bin/tapioca gem redis-actionpack`.

# source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#7
module ActionDispatch
  # source://actionpack/7.0.5/lib/action_dispatch.rb#99
  def test_app; end

  # source://actionpack/7.0.5/lib/action_dispatch.rb#99
  def test_app=(val); end

  class << self
    # source://actionpack/7.0.5/lib/action_dispatch.rb#99
    def test_app; end

    # source://actionpack/7.0.5/lib/action_dispatch.rb#99
    def test_app=(val); end
  end
end

# source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#8
module ActionDispatch::Session; end

# Session storage in Redis, using +Redis::Rack+ as a basis.
#
# source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#10
class ActionDispatch::Session::RedisStore < ::Rack::Session::Redis
  include ::ActionDispatch::Session::Compatibility
  include ::ActionDispatch::Session::StaleSessionCheck
  include ::ActionDispatch::Session::SessionObject

  # @return [RedisStore] a new instance of RedisStore
  #
  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#15
  def initialize(app, options = T.unsafe(nil)); end

  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#21
  def generate_sid; end

  private

  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#45
  def cookie_jar(request); end

  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#41
  def cookie_options; end

  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#32
  def get_cookie(request); end

  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#27
  def set_cookie(env, _session_id, cookie); end

  # source://redis-actionpack//lib/action_dispatch/middleware/session/redis_store.rb#36
  def wrap_in_request(env); end
end

# source://redis-actionpack//lib/redis/actionpack/version.rb#1
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

# source://redis-actionpack//lib/redis/actionpack/version.rb#2
module Redis::ActionPack; end

# source://redis-actionpack//lib/redis/actionpack/version.rb#3
Redis::ActionPack::VERSION = T.let(T.unsafe(nil), String)

# source://redis/4.8.1/lib/redis.rb#8
Redis::BASE_PATH = T.let(T.unsafe(nil), String)

# source://redis/4.8.1/lib/redis/version.rb#4
Redis::VERSION = T.let(T.unsafe(nil), String)
