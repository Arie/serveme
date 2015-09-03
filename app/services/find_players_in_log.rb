class FindPlayersInLog

  attr_accessor :log, :players

  PLAYER_JOINED_REGEX = /L (?'time'.*): "(?'player_nick'.+)<(?'player_uid'\d+)><(?'player_steamid'(\[\S+\]|STEAM_\S+))><>" STEAM USERID validated/

  def self.perform(log)
    finder = new(log)
    finder.parse_log
    finder.players
  end

  def initialize(log)
    @log = File.open(log)
  end

  def parse_log
    log.each_line do |line|
      player_steamid = find_player_in_line(line)
      players << player_steamid if player_steamid
    end
  end

  def players
    @players ||= []
  end

  def find_player_in_line(line)
    begin
      match = line.match(PLAYER_JOINED_REGEX)
    rescue ArgumentError
      tidied_line = ActiveSupport::Multibyte::Chars.new(line).tidy_bytes
      match = tidied_line.match(PLAYER_JOINED_REGEX)
    end
    if match
      convert_steam_id_to_community_id(match[:player_steamid])
    end
  end

  def convert_steam_id_to_community_id(steam_id)
    SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
  end
end
