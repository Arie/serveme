# typed: true
# frozen_string_literal: true

require "net/http"
require "uri"
require "timeout"

class LeagueMapsSyncService
  extend T::Sig

  GITHUB_RAW_URL = "https://raw.githubusercontent.com/Arie/serveme/refs/heads/master/config/league_maps.yml"
  CACHE_KEY = "league_maps_config"
  CACHE_EXPIRY = 24.hours

  sig { returns(T::Boolean) }
  def self.fetch_and_apply
    new.fetch_and_apply
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def self.fetch_for_preview
    new.fetch_from_github
  end

  sig { params(config: T::Hash[String, T.untyped]).returns(T::Boolean) }
  def self.apply_config(config)
    new.apply_config(config)
  end

  sig { returns(T::Boolean) }
  def fetch_and_apply
    config = fetch_from_github
    return false if config.empty?

    validation_result = validate_config(config)
    return false unless validation_result[:valid]

    apply_config(config)
    log_sync_success(config)
    true
  rescue => e
    log_sync_error(e)
    false
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def fetch_from_github
    uri = URI(GITHUB_RAW_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    http.read_timeout = 10
    http.open_timeout = 5

    response = http.get(uri.path)

    if response.code == "200"
      yaml_content = response.body
      config = YAML.safe_load(T.must(yaml_content), permitted_classes: [ Symbol ])
      config
    else
      {}
    end
  rescue => e
    Rails.logger.error("Error fetching from GitHub: #{e.class} - #{e.message}")
    {}
  end

  sig { params(config: T::Hash[String, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
  def validate_config(config)
    errors = []
    warnings = []

    unless config["league_maps"].is_a?(Array)
      errors << "Invalid YAML structure - expected 'league_maps' array at root level"
      return { valid: false, errors: errors, warnings: warnings }
    end

    league_maps = config["league_maps"]

    if league_maps.empty?
      errors << "No league maps defined"
      return { valid: false, errors: errors, warnings: warnings }
    end

    league_names = []
    available_maps = MapUpload.available_maps

    league_maps.each_with_index do |league, index|
      unless league.is_a?(Hash)
        errors << "League at index #{index} is not a hash"
        next
      end

      name = league["name"]
      maps = league["maps"]

      if name.blank?
        errors << "League at index #{index} missing required 'name' field"
        next
      end

      if league_names.include?(name)
        errors << "Duplicate league name: #{name}"
      end
      league_names << name

      unless maps.is_a?(Array)
        errors << "League '#{name}' missing or invalid 'maps' array"
        next
      end

      if maps.empty?
        warnings << "League '#{name}' has no maps defined"
      end

      maps.each do |map_name|
        unless map_name.is_a?(String) && map_name.present?
          errors << "League '#{name}' contains invalid map name: #{map_name.inspect}"
          next
        end

        unless available_maps.include?(map_name)
          warnings << "League '#{name}' contains unknown map: #{map_name}"
        end
      end

      duplicate_maps = maps.group_by(&:itself).select { |_, v| v.size > 1 }.keys
      if duplicate_maps.any?
        warnings << "League '#{name}' has duplicate maps: #{duplicate_maps.join(', ')}"
      end
    end

    {
      valid: errors.empty?,
      errors: errors,
      warnings: warnings
    }
  end

  sig { params(config: T::Hash[String, T.untyped]).returns(T::Boolean) }
  def apply_config(config)
    Rails.cache.write(CACHE_KEY, config, expires_in: CACHE_EXPIRY)
    Rails.cache.write("#{CACHE_KEY}_last_sync", Time.current, expires_in: CACHE_EXPIRY)

    write_local_config(config)

    true
  rescue => e
    Rails.logger.error("Failed to apply config: #{e.message}")
    false
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def current_config
    Rails.cache.fetch(CACHE_KEY) do
      load_local_fallback
    end
  end

  sig { returns(T.nilable(Time)) }
  def last_sync_time
    Rails.cache.read("#{CACHE_KEY}_last_sync")
  end

  sig { params(new_config: T::Hash[String, T.untyped], current_config: T.nilable(T::Hash[String, T.untyped])).returns(T::Hash[Symbol, T.untyped]) }
  def generate_diff(new_config, current_config = nil)
    current = current_config || self.current_config
    current_leagues = T.let(current["league_maps"], T.nilable(T::Array[T::Hash[String, T.untyped]])) || []
    new_leagues = T.let(new_config["league_maps"], T.nilable(T::Array[T::Hash[String, T.untyped]])) || []

    {
      added_leagues: new_leagues.map { |l| l["name"] } - current_leagues.map { |l| l["name"] },
      removed_leagues: current_leagues.map { |l| l["name"] } - new_leagues.map { |l| l["name"] },
      modified_leagues: find_modified_leagues(current_leagues, new_leagues)
    }
  end

  private

  sig { params(config: T::Hash[String, T.untyped]).void }
  def log_sync_success(config)
    league_count = config["league_maps"]&.size || 0
    total_maps = config["league_maps"]&.sum { |l| l["maps"]&.size || 0 } || 0

    Rails.logger.info(
      "League maps sync successful: #{league_count} leagues, #{total_maps} total maps"
    )
  end

  sig { params(error: Exception).void }
  def log_sync_error(error)
    Rails.logger.error(
      "League maps sync failed: #{error.class} - #{error.message}\n#{error.backtrace&.join("\n")}"
    )
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def load_local_fallback
    yaml_path = Rails.root.join("config", "league_maps.yml")
    YAML.safe_load(File.read(yaml_path), permitted_classes: [ Symbol ])
  rescue => e
    Rails.logger.error("Failed to load league_maps.yml: #{e.message}")
    { "league_maps" => [] }
  end

  sig { params(config: T::Hash[String, T.untyped]).void }
  def write_local_config(config)
    if Rails.env.test?
      yaml_path = Rails.root.join("tmp", "test_league_maps.yml")
    else
      yaml_path = Rails.root.join("config", "league_maps.yml")
    end

    File.write(yaml_path, config.to_yaml)
    Rails.logger.info("Written league maps config to local file: #{yaml_path}")
  rescue => e
    Rails.logger.error("Failed to write local config file: #{e.message}")
  end

  sig { params(current: T::Array[T::Hash[String, T.untyped]], new_leagues: T::Array[T::Hash[String, T.untyped]]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def find_modified_leagues(current, new_leagues)
    modified = []

    new_leagues.each do |new_league|
      name = new_league["name"]
      current_league = current.find { |l| l["name"] == name }

      if current_league && current_league["maps"] != new_league["maps"]
        added_maps = new_league["maps"] - current_league["maps"]
        removed_maps = current_league["maps"] - new_league["maps"]

        modified << {
          name: name,
          added_maps: added_maps,
          removed_maps: removed_maps
        }
      end
    end

    modified
  end
end
