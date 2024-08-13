# frozen_string_literal: true

class RglApi
  def self.profile(steam_uid)
    cached_profile_response(steam_uid) || fetch_profile(steam_uid)
  end

  def self.cached_profile_response(steam_uid)
    Rails.cache.read("rgl_profile_#{steam_uid}")
  end

  def self.fetch_profile(steam_uid)
    response = rgl_connection.get("v0/profile/#{steam_uid}")
    return unless response.success? || response.status == 404

    Rails.cache.write("rgl_profile_#{steam_uid}", response.body, expires_in: 1.day)

    response.body
  end

  def self.rgl_connection
    Faraday.new(url: 'https://api.rgl.gg/')
  end
end
