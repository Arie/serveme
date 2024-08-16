# typed: true
# frozen_string_literal: true

class RglApi
  extend T::Sig

  sig { params(steam_uid: T.any(String, Integer)).returns(T.nilable(String)) }
  def self.profile(steam_uid)
    cached_profile_response(steam_uid) || fetch_profile(steam_uid)
  end

  sig { params(steam_uid: T.any(String, Integer)).returns(T.nilable(String)) }
  def self.cached_profile_response(steam_uid)
    Rails.cache.read("rgl_profile_#{steam_uid}")
  end

  sig { params(steam_uid: T.any(String, Integer)).returns(T.nilable(String)) }
  def self.fetch_profile(steam_uid)
    response = rgl_connection.get("v0/profile/#{steam_uid}")
    return unless response.success? || response.status == 404

    Rails.cache.write("rgl_profile_#{steam_uid}", response.body, expires_in: 1.day)

    response.body
  end

  sig { returns(Faraday::Connection) }
  def self.rgl_connection
    Faraday.new(request: { open_timeout: 5, timeout: 5 }, url: 'https://api.rgl.gg/')
  end
end
