# typed: strict
# frozen_string_literal: true

module CloudProvider
  extend T::Sig

  PROVIDERS = T.let({
    "hetzner" => Hetzner,
    "vultr" => Vultr,
    "docker" => Docker
  }.freeze, T::Hash[String, T.class_of(Base)])

  sig { params(provider_name: String).returns(CloudProvider::Base) }
  def self.for(provider_name)
    klass = PROVIDERS[provider_name]
    raise ArgumentError, "Unknown cloud provider: #{provider_name}" unless klass

    klass.new
  end

  # Returns cloud locations grouped by region for use in select dropdowns.
  # Each entry is [label, value] where value is "provider:code".
  # { "EU" => [["Frankfurt (Hetzner)", "hetzner:fsn1"], ...], "NA" => [...] }
  sig { returns(T::Hash[String, T::Array[[ String, String ]]]) }
  def self.grouped_locations
    grouped = Hash.new { |h, k| h[k] = [] }

    PROVIDERS.each do |provider_name, klass|
      klass.locations.each do |code, info|
        label = "#{info[:name]}, #{info[:country]} (#{provider_name.capitalize})"
        value = "#{provider_name}:#{code}"
        grouped[info[:region]] << [ label, value ]
      end
    end

    grouped.each_value { |locs| locs.sort_by! { |label, _| label } }
    grouped.sort_by { |region, _| %w[EU NA AU SEA].index(region) || 99 }.to_h
  end
end
