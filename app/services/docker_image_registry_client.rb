# typed: true
# frozen_string_literal: true

class DockerImageRegistryClient
  IMAGE = "serveme/tf2-cloud-server"

  def fetch_digest
    auth_conn = Faraday.new(url: "https://auth.docker.io") do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
    token_response = auth_conn.get("/token?service=registry.docker.io&scope=repository:#{IMAGE}:pull")
    return nil unless token_response.success?

    token = JSON.parse(token_response.body)["token"]

    registry_conn = Faraday.new(url: "https://registry-1.docker.io") do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
    manifest_response = registry_conn.head("/v2/#{IMAGE}/manifests/latest") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Accept"] = "application/vnd.docker.distribution.manifest.v2+json"
    end

    manifest_response.headers["docker-content-digest"]
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn "DockerImageRegistryClient: Failed to check registry: #{e.message}"
    nil
  end
end
