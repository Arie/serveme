# typed: true
# frozen_string_literal: true

class OzfortressProfile
  extend T::Sig

  DIVISION_TIERS = {
    "Premier" => 0,
    "High" => 1,
    "Intermediate" => 2,
    "Main" => 3,
    "Open" => 4,
    "Division 1" => 1,
    "Division 2" => 2,
    "Division 3" => 3,
    "Division 4" => 4,
    "Division 5" => 5
  }.freeze

  attr_reader :json

  sig { params(profile_body: String).void }
  def initialize(profile_body)
    @json = JSON.parse(profile_body)
  end

  sig { returns(T.nilable(String)) }
  def highest_division
    rosters = json.dig("user", "rosters")
    return nil unless rosters.is_a?(Array)

    best_tier = T.let(nil, T.nilable(Integer))
    best_name = T.let(nil, T.nilable(String))

    rosters.each do |roster|
      div = roster["division"]
      next unless div

      tier = DIVISION_TIERS[div]
      next unless tier

      if best_tier.nil? || tier < best_tier
        best_tier = tier
        best_name = div
      end
    end

    best_name
  end

  sig { params(steam_uid: T.any(Integer, String)).returns(T.nilable(OzfortressProfile)) }
  def self.fetch(steam_uid)
    response_body = OzfortressApi.profile(steam_uid)
    new(response_body) if response_body
  end
end
