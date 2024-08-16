# frozen_string_literal: true

class Etf2lProfile
  attr_accessor :json

  def initialize(profile_body)
    @json = JSON.parse(profile_body)
  end

  def name
    json.dig('player', 'name')
  end

  def banned?
    active_bans.any?
  end

  def ban_reason
    return nil if active_bans.none?

    active_bans.map { |b| b['reason'] }.join(', ')
  end

  def ban_expires_at
    return nil if active_bans.none?

    active_bans.map { |b| Time.at(b['end']).to_date }.join(', ')
  end

  def self.fetch(steam_uid)
    response_body = Etf2lApi.profile(steam_uid)
    new(response_body) if response_body
  end

  def self.league_name
    'ETF2L'
  end

  private

  def active_bans
    @active_bans ||= begin
      now = Time.now.to_i
      bans = json.dig('player', 'bans')
      if bans&.any?
        bans.reject { |b| now > b['end'].to_i }
      else
        []
      end
    end
  end
end
