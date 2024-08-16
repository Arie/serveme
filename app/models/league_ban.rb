# typed: true
# frozen_string_literal: true

class LeagueBan
  extend T::Sig

  sig { params(steam_uid: T.any(String, Integer)).returns(T.nilable(T.any(Etf2lProfile, RglProfile))) }
  def self.fetch(steam_uid)
    profile = klass&.fetch(steam_uid)
    profile if profile&.banned?
  rescue Faraday::TimeoutError
    nil
  end

  sig { returns(T.nilable(T.any(T.class_of(Etf2lProfile), T.class_of(RglProfile)))) }
  def self.klass
    if SITE_HOST == 'serveme.tf'
      Etf2lProfile
    elsif SITE_HOST == 'na.serveme.tf'
      RglProfile
    end
  end

  def self.league_name
    klass&.league_name
  end
end
