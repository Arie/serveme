# typed: true
# frozen_string_literal: true

class UserSearchService
  extend T::Sig

  sig { params(input: T.nilable(String)).void }
  def initialize(input)
    @input = input.to_s.strip
  end

  sig { returns(T::Array[User]) }
  def search
    return [] if @input.blank?

    # For exact ID matches, return just that user
    if (user = find_by_user_id || find_by_steam_id64 || find_by_steam_id || find_by_steam_id3 || find_by_steam_url)
      # Reload with includes to avoid N+1
      return User.includes(:group_users).where(id: user.id).to_a
    end

    # For nickname search, return multiple results
    search_by_nickname
  end

  private

  sig { returns(T.nilable(User)) }
  def find_by_user_id
    return nil unless @input.match?(/^#?\d+$/)

    user_id = @input.gsub("#", "").to_i
    User.find_by(id: user_id)
  end

  sig { returns(T.nilable(User)) }
  def find_by_steam_id64
    return nil unless @input.match?(/^\d{17}$/)

    User.find_by(uid: @input)
  end

  sig { returns(T.nilable(User)) }
  def find_by_steam_id
    return nil unless @input.match?(/^STEAM_[0-5]:[01]:\d+$/i)

    begin
      steam_id64 = SteamCondenser::Community::SteamId.steam_id_to_community_id(@input)
      User.find_by(uid: steam_id64.to_s)
    rescue StandardError
      nil
    end
  end

  sig { returns(T.nilable(User)) }
  def find_by_steam_id3
    return nil unless @input.match?(/^\[U:1:\d+\]$/i)

    begin
      steam_id64 = SteamCondenser::Community::SteamId.steam_id_to_community_id(@input)
      User.find_by(uid: steam_id64.to_s)
    rescue StandardError
      nil
    end
  end

  sig { returns(T.nilable(User)) }
  def find_by_steam_url
    return nil unless @input.match?(/steamcommunity\.com/)

    if (match = @input.match(/steamcommunity\.com\/profiles\/(\d{17})/))
      return User.find_by(uid: match[1])
    end

    if (match = @input.match(/steamcommunity\.com\/id\/([a-zA-Z0-9_-]+)/))
      begin
        steam_id64 = SteamCondenser::Community::SteamId.resolve_vanity_url(match[1])
        return User.find_by(uid: steam_id64.to_s) if steam_id64
      rescue SteamCondenser::Error::Timeout, Net::ReadTimeout, Faraday::TimeoutError => e
        Rails.logger.info "Steam API timeout when resolving vanity URL: #{e.message}"
      rescue StandardError => e
        Rails.logger.error "Failed to resolve vanity URL: #{e.message}"
      end
    end

    nil
  end

  sig { returns(T::Array[User]) }
  def search_by_nickname
    return [] if @input.match?(/^#?\d+$/) || @input.match?(/^\[U:\d:\d+\]$/i) || @input.match?(/^STEAM_[0-5]:[01]:\d+$/i)

    User.includes(:group_users)
        .where("LOWER(nickname) LIKE ?", "%#{@input.downcase}%")
        .order(
          Arel.sql("CASE WHEN LOWER(nickname) = #{User.connection.quote(@input.downcase)} THEN 0 WHEN LOWER(nickname) LIKE #{User.connection.quote("#{@input.downcase}%")} THEN 1 ELSE 2 END"),
          :nickname
        )
        .limit(5)
        .to_a
  end
end
