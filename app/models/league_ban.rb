# typed: true
# frozen_string_literal: true

class LeagueBan
  def self.fetch(steam_uid)
    return unless klass

    profile = klass.fetch(steam_uid)
    profile&.banned? && profile
  rescue Faraday::TimeoutError
    nil
  end

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
