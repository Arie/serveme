# frozen_string_literal: true

class LeagueBan
  def self.fetch(steam_uid)
    klass = if SITE_HOST == 'serveme.tf'
              Etf2lProfile
            elsif SITE_HOST == 'na.serveme.tf'
              RglProfile
            end

    return unless klass

    profile = klass.fetch(steam_uid)
    profile.banned? && profile
  end
end
