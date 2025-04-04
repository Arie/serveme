# typed: true
# frozen_string_literal: true

require "nokogiri"

class RglProfile
  extend T::Sig
  attr_accessor :json

  sig { params(profile_body: String).void }
  def initialize(profile_body)
    @json = JSON.parse(profile_body)
  end

  sig { returns(String) }
  def league_name
    "RGL"
  end

  sig { returns(String) }
  def name
    json["name"]
  end

  sig { returns(T::Boolean) }
  def banned?
    json.dig("status", "isBanned") == true
  end

  sig { returns(T.nilable(String)) }
  def ban_reason
    reason = json.dig("banInformation", "reason")
    return unless reason
    reason = reason.gsub(/<br\s*\/?>/, " ")
    Nokogiri::HTML(reason).text.strip
  end

  def ban_expires_at
    expires_at = json.dig("banInformation", "endsAt")
    expires_at && Date.parse(expires_at)
  end

  sig { params(steam_uid: T.any(Integer, String)).returns(T.nilable(RglProfile)) }
  def self.fetch(steam_uid)
    response_body = RglApi.profile(steam_uid)
    new(response_body) if response_body
  end
end
