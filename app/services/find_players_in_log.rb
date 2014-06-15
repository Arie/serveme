class FindPlayersInLog

  attr_accessor :log, :players

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
    regex = /L (?'time'.*): "(?'player_nick'.+)<(?'player_uid'\d+)><(?'player_steamid'STEAM_\S+)><>" STEAM USERID validated/
    begin
      match = line.match(regex)
    rescue ArgumentError
      tidied_line = ActiveSupport::Multibyte::Chars.new(line).tidy_bytes
      match = tidied_line.match(regex)
    end
    if match
      convert_steam_id_to_community_id(match[:player_steamid])
    end
  end

  def convert_steam_id_to_community_id(steam_id)
    SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
  end
end
