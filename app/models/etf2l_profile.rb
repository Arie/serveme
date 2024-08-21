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
    'ETF2L'
  end

  sig { returns(T.nilable(String)) }
  def name
    json.dig('player', 'name')
  end

  sig { returns(T::Boolean) }
  def banned?
    active_bans.any?
  end

  sig { returns(T.nilable(String)) }
  def ban_reason
    return nil if active_bans.none?

    active_bans.map { |b| b['reason'] }.join(', ')
  end

  sig { returns(T.nilable(String)) }
  def ban_expires_at
    return nil if active_bans.none?

    active_bans.map { |b| Time.at(b['end']).to_date }.join(', ')
  end

  sig { params(steam_uid: T.any(Integer, String)).returns(T.nilable(Etf2lProfile)) }
  def self.fetch(steam_uid)
    response_body = Etf2lApi.profile(steam_uid)
    new(response_body) if response_body
  end

  private

  sig { returns(T::Array[Hash]) }
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
