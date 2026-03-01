# typed: strict
# frozen_string_literal: true

module CloudProvider
  extend T::Sig

  PROVIDERS = T.let({
    "hetzner" => Hetzner,
    "vultr" => Vultr,
    "docker" => Docker,
    "remote_docker" => RemoteDocker
  }.freeze, T::Hash[String, T.class_of(Base)])

  sig { params(provider_name: String).returns(CloudProvider::Base) }
  def self.for(provider_name)
    klass = PROVIDERS[provider_name]
    raise ArgumentError, "Unknown cloud provider: #{provider_name}" unless klass

    klass.new
  end

  SITE_REGION = T.let(
    case SITE_HOST
    when "na.serveme.tf" then "NA"
    when "au.serveme.tf" then "AU"
    when "sea.serveme.tf" then "SEA"
    else "EU"
    end.freeze, String
  )

  # Returns cloud locations grouped by country for use in select dropdowns.
  # Each entry is [label, value] where value is "provider:code".
  # Filtered to only show locations matching the current site region.
  sig { params(starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(T::Hash[String, T::Array[[ String, String ]]]) }
  def self.grouped_locations(starts_at: Time.current, ends_at: 2.hours.from_now)
    grouped = Hash.new { |h, k| h[k] = [] }

    PROVIDERS.each do |provider_name, klass|
      klass.locations(starts_at: starts_at, ends_at: ends_at).each do |code, info|
        next unless info[:region] == SITE_REGION || provider_name.in?(%w[docker remote_docker])

        label = if provider_name == "remote_docker"
          "#{info[:name]} (#{SITE_HOST})"
        else
          "#{info[:name]} (#{provider_name.capitalize})"
        end
        value = "#{provider_name}:#{code}"
        grouped[info[:country]] << [ label, value ]
      end
    end

    grouped.each_value { |locs| locs.sort_by! { |label, _| label } }
    grouped.sort_by { |country, _| country }.to_h
  end
end
