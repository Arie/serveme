# typed: strict

module OpenAI
  class Client
    sig { params(access_token: String, uri_base: String, request_timeout: Integer).void }
    def initialize(access_token:, uri_base:, request_timeout:); end

    sig { params(parameters: T::Hash[Symbol, T.untyped]).returns(T::Hash[String, T.untyped]) }
    def chat(parameters:); end
  end
end
