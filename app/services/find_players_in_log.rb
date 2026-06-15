# typed: true
# frozen_string_literal: true

class FindPlayersInLog
  extend T::Sig

  attr_accessor :log

  PLAYER_JOINED_REGEX = /L (?'time'.*): "(?'player_nick'.+)<(?'player_uid'\d+)><(?'player_steamid'(\[\S+\]|STEAM_\S+))><>" STEAM USERID validated/

  sig { params(log: T.untyped).returns(T::Array[T.untyped]) }
  def self.perform(log)
    finder = new(log)
    finder.parse_log
    finder.players
  end

  sig { params(log: T.untyped).void }
  def initialize(log)
    @log = File.open(log)
  end

  sig { void }
  def parse_log
    log.each_line do |line|
      player_steamid = find_player_in_line(line)
      players << player_steamid if player_steamid
    end
  end

  sig { returns(T::Array[T.untyped]) }
  def players
    @players ||= []
  end

  sig { params(line: String).returns(T.untyped) }
  def find_player_in_line(line)
    begin
      match = line.match(PLAYER_JOINED_REGEX)
    rescue ArgumentError
      tidied_line = StringSanitizer.tidy_bytes(line)
      match = tidied_line.match(PLAYER_JOINED_REGEX)
    end
    convert_steam_id_to_community_id(match[:player_steamid]) if match
  end

  sig { params(steam_id: T.untyped).returns(T.untyped) }
  def convert_steam_id_to_community_id(steam_id)
    SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
  end
end
