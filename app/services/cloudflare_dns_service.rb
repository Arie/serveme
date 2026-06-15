# typed: true
# frozen_string_literal: true

class CloudflareDnsService
  extend T::Sig

  class Error < StandardError; end

  BASE_URL = "https://api.cloudflare.com/client/v4"

  sig { params(hostname: T.nilable(String), ip: T.nilable(String)).returns(T.nilable(String)) }
  def create_a_record(hostname, ip)
    response = post("zones/#{zone_id}/dns_records", {
      type: "A",
      name: hostname,
      content: ip,
      proxied: false,
      ttl: 1
    })

    body = JSON.parse(T.must(response.body))
    raise Error, error_message(body) unless body["success"]

    body.dig("result", "id")
  end

  sig { params(hostname: T.nilable(String)).returns(T.nilable(Net::HTTPResponse)) }
  def delete_a_record(hostname)
    record_id = find_record_id(hostname)
    return unless record_id

    delete("zones/#{zone_id}/dns_records/#{record_id}")
  end

  sig { params(hostname: T.nilable(String)).returns(T::Boolean) }
  def record_exists?(hostname)
    find_record_id(hostname).present?
  end

  sig { params(hostname: T.nilable(String), ip: T.nilable(String)).returns(T.nilable(String)) }
  def update_a_record(hostname, ip)
    record_id = find_record_id(hostname)
    raise Error, "No A record found for #{hostname}" unless record_id

    response = patch("zones/#{zone_id}/dns_records/#{record_id}", {
      type: "A",
      name: hostname,
      content: ip,
      proxied: false,
      ttl: 1
    })

    body = JSON.parse(T.must(response.body))
    raise Error, error_message(body) unless body["success"]

    body.dig("result", "id")
  end

  private

  sig { params(hostname: T.nilable(String)).returns(T.nilable(String)) }
  def find_record_id(hostname)
    uri = URI("#{BASE_URL}/zones/#{zone_id}/dns_records?type=A&name=#{hostname}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{api_token}"

    response = http.request(request)
    body = JSON.parse(response.body)
    body.dig("result", 0, "id")
  end

  sig { params(path: String, data: T::Hash[Symbol, T.untyped]).returns(Net::HTTPResponse) }
  def post(path, data)
    uri = URI("#{BASE_URL}/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_token}"
    request["Content-Type"] = "application/json"
    request.body = data.to_json

    http.request(request)
  end

  sig { params(path: String, data: T::Hash[Symbol, T.untyped]).returns(Net::HTTPResponse) }
  def patch(path, data)
    uri = URI("#{BASE_URL}/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Patch.new(uri)
    request["Authorization"] = "Bearer #{api_token}"
    request["Content-Type"] = "application/json"
    request.body = data.to_json

    http.request(request)
  end

  sig { params(path: String).returns(Net::HTTPResponse) }
  def delete(path)
    uri = URI("#{BASE_URL}/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = "Bearer #{api_token}"

    http.request(request)
  end

  sig { returns(T.nilable(String)) }
  def zone_id
    Rails.application.credentials.dig(:cloudflare, :dns_zone_id)
  end

  sig { returns(T.nilable(String)) }
  def api_token
    Rails.application.credentials.dig(:cloudflare, :dns_api_token)
  end

  sig { params(body: T::Hash[String, T.untyped]).returns(String) }
  def error_message(body)
    errors = body["errors"] || []
    errors.map { |e| e["message"] }.join(", ")
  end
end
