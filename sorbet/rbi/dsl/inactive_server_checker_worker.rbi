# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `InactiveServerCheckerWorker`.
# Please instead update this file by running `bin/tapioca dsl InactiveServerCheckerWorker`.

class InactiveServerCheckerWorker
  class << self
    sig { params(server_id: T.untyped).returns(String) }
    def perform_async(server_id); end

    sig { params(interval: T.any(DateTime, Time), server_id: T.untyped).returns(String) }
    def perform_at(interval, server_id); end

    sig { params(interval: Numeric, server_id: T.untyped).returns(String) }
    def perform_in(interval, server_id); end
  end
end
