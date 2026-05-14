# typed: true
# frozen_string_literal: true

class DockerImageRegistryClient
  IMAGE = "serveme/tf2-cloud-server"

  # The content digest of the :latest manifest, or nil on failure.
  def fetch_digest
    token = fetch_token
    return nil unless token

    manifest_response = registry_connection.head("/v2/#{IMAGE}/manifests/latest") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Accept"] = "application/vnd.docker.distribution.manifest.v2+json"
    end

    manifest_response.headers["docker-content-digest"]
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn "DockerImageRegistryClient: Failed to check registry: #{e.message}"
    nil
  end

  # The highest numeric (TF2 version) tag in the registry as a string, or nil
  # when there are no version tags or the lookup fails.
  def fetch_latest_version_tag
    token = fetch_token
    return nil unless token

    tags_response = registry_connection.get("/v2/#{IMAGE}/tags/list") do |req|
      req.headers["Authorization"] = "Bearer #{token}"
    end
    return nil unless tags_response.success?

    tags = JSON.parse(tags_response.body)["tags"] || []
    tags.select { |tag| tag.match?(/\A\d+\z/) }.map(&:to_i).max&.to_s
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn "DockerImageRegistryClient: Failed to fetch tags: #{e.message}"
    nil
  end

  private

  # Memoized so a single client instance reuses one token across calls
  # (e.g. DockerImagePollWorker calls fetch_digest + fetch_latest_version_tag).
  def fetch_token
    @token ||= begin
      auth_conn = Faraday.new(url: "https://auth.docker.io") do |f|
        f.options.timeout = 10
        f.options.open_timeout = 5
      end
      token_response = auth_conn.get("/token?service=registry.docker.io&scope=repository:#{IMAGE}:pull")
      JSON.parse(token_response.body)["token"] if token_response.success?
    end
  end

  def registry_connection
    Faraday.new(url: "https://registry-1.docker.io") do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
    end
  end
end
