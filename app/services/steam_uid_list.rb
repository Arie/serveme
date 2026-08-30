# typed: strict
# frozen_string_literal: true

# The steam_uids parameter shared by the reservations API and the list_reservations MCP tool:
# an array or comma separated string of Steam ID64s, optionally combined with a singular steam_uid
module SteamUidList
  extend T::Sig

  MAX = 50
  TOO_MANY_ERROR = "Too many steam uids, maximum is #{MAX}"

  sig { params(steam_uids: T.untyped, steam_uid: T.untyped).returns(T::Array[String]) }
  def self.parse(steam_uids, steam_uid = nil)
    values = steam_uids.is_a?(Array) ? steam_uids : steam_uids.to_s.split(",")
    (values + [ steam_uid ]).map { |uid| uid.to_s.strip }.reject(&:blank?).uniq
  end

  sig { params(steam_uids: T::Array[String]).returns(T::Boolean) }
  def self.too_many?(steam_uids)
    steam_uids.size > MAX
  end
end
