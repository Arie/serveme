# frozen_string_literal: true

class RglProfile
  attr_accessor :json

  def initialize(profile_body)
    @json = JSON.parse(profile_body)
  end

  def name
    json['name']
  end

  def banned?
    json.dig('status', 'isBanned') == true
  end

  def ban_reason
    reason = json.dig('banInformation', 'reason')
    ActionView::Base.full_sanitizer.sanitize(reason) if reason
  end

  def ban_expires_at
    expires_at = json.dig('banInformation', 'endsAt')
    expires_at && Date.parse(expires_at)
  end

  def self.fetch(steam_uid)
    response_body = RglApi.profile(steam_uid)
    new(response_body) if response_body
  end

  def self.league_name
    "RGL"
  end
end
