# typed: true
# frozen_string_literal: true

class UserFinderService
  extend T::Sig

  sig { params(input: T.nilable(String)).void }
  def initialize(input)
    @input = input.to_s.strip
  end

  sig { returns(T.nilable(User)) }
  def find
    return nil if @input.blank?

    find_by_user_id ||
      find_by_steam_id64 ||
      find_by_steam_id ||
      find_by_steam_id3 ||
      find_by_nickname
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
  def find_by_nickname
    return nil if @input.match?(/^#?\d+$/) || @input.match?(/^\[U:\d:\d+\]$/i) || @input.match?(/^STEAM_[0-5]:[01]:\d+$/i)

    User.where("LOWER(nickname) LIKE ?", "%#{@input.downcase}%").first
  end
end
