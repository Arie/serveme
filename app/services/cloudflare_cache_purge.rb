# typed: true
# frozen_string_literal: true

# fastdl.serveme.tf is cached at Cloudflare's edge (max-age 5 days), so
# replacing an object in R2 stays invisible to clients until its cached copy is
# purged.
class CloudflareCachePurge
  extend T::Sig

  class Error < StandardError; end

  BASE_URL = "https://api.cloudflare.com/client/v4"
  URLS_PER_REQUEST = 30

  sig { params(urls: T::Array[String]).void }
  def purge(urls)
    urls.each_slice(URLS_PER_REQUEST) { |batch| purge_batch(batch) }
  end

  private

  sig { params(urls: T::Array[String]).void }
  def purge_batch(urls)
    uri = URI("#{BASE_URL}/zones/#{zone_id}/purge_cache")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_token}"
    request["Content-Type"] = "application/json"
    request.body = { files: urls }.to_json

    body = JSON.parse(http.request(request).body.to_s)
    raise Error, error_message(body) unless body["success"]
  end

  sig { returns(T.nilable(String)) }
  def zone_id
    Rails.application.credentials.dig(:cloudflare, :dns_zone_id)
  end

  sig { returns(T.nilable(String)) }
  def api_token
    Rails.application.credentials.dig(:cloudflare, :dns_api_token)
  end

  sig { params(body: T.untyped).returns(String) }
  def error_message(body)
    Array(body["errors"]).map { |error| error["message"] }.join(", ").presence || "purge failed"
  end
end
