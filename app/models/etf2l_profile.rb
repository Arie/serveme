# typed: true
# frozen_string_literal: true

class Etf2lProfile
  extend T::Sig
  attr_accessor :json

  sig { params(profile_body: String).void }
  def initialize(profile_body)
    @json = JSON.parse(profile_body)
  end

  sig { returns(String) }
  def league_name
    "ETF2L"
  end

  sig { returns(T.nilable(String)) }
  def name
    json.dig("player", "name")
  end

  sig { returns(T::Boolean) }
  def banned?
    active_bans.any?
  end

  sig { returns(T.nilable(String)) }
  def ban_reason
    return nil if active_bans.none?

    active_bans.map { |b| b["reason"] }.join(", ")
  end

  sig { returns(T.nilable(String)) }
  def ban_expires_at
    return nil if active_bans.none?

    active_bans.map { |b| Time.at(b["end"]).to_date }.join(", ")
  end

  sig { params(steam_uid: T.any(Integer, String)).returns(T.nilable(Etf2lProfile)) }
  def self.fetch(steam_uid)
    response_body = Etf2lApi.profile(steam_uid)
    new(response_body) if response_body
  end

  sig { returns(T.nilable(String)) }
  def highest_division
    best_tier = T.let(nil, T.nilable(Integer))
    best_name = T.let(nil, T.nilable(String))
    teams = json.dig("player", "teams")
    return nil unless teams.is_a?(Array)

    teams.each do |team|
      competitions = team["competitions"]
      next unless competitions.is_a?(Hash)

      competitions.each_value do |comp|
        category = comp["category"]
        next unless category&.include?("Season")

        tier = comp.dig("division", "tier")
        next unless tier.is_a?(Integer)

        if best_tier.nil? || tier < best_tier
          best_tier = tier
          div_name = comp.dig("division", "name")
          comp_name = extract_season_name(comp["competition"])
          best_name = comp_name ? "#{div_name} (#{comp_name})" : div_name
        end
      end
    end

    best_name
  end

  private

  def extract_season_name(competition)
    return nil unless competition

    match = competition.match(/Season (\d+)/i)
    match ? "S#{match[1]}" : competition
  end

  sig { returns(T::Array[Hash]) }
  def active_bans
    @active_bans ||= begin
      now = Time.now.to_i
      bans = json.dig("player", "bans")
      if bans&.any?
        bans.reject { |b| now > b["end"].to_i }
      else
        []
      end
    end
  end
end
