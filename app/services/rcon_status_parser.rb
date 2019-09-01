# frozen_string_literal: true
class RconStatusParser

  attr_accessor :rcon_status_output

  PLAYER_REGEX = /\#\s+\d+\s+\"(.*)"\s+(\[.*\])\s+(\d+:?\d+:\d+)\s+(\d+)\s+(\d+)\s(\w+)\s+(\d+.\d+.\d+.\d+)/

  def initialize(rcon_status_output)
    @rcon_status_output = rcon_status_output
  end

  def scan
    rcon_status_output.scan(PLAYER_REGEX)
  end

  def players
    @players ||=  begin
                    scan.collect do |player_array|
                      Player.new(*player_array)
                    end
                  end
  end


  class Player

    attr_reader :name, :steam_id, :connect_duration, :ping, :loss, :state, :ip

    def initialize(name, steam_id, connect_duration, ping, loss, state, ip)
      @name             = name
      @steam_id         = steam_id
      @connect_duration = connect_duration
      @ping             = ping.to_i
      @loss             = loss.to_i
      @state            = state
      @ip               = ip
    end

    def relevant?
      active?
    end

    def active?
      state == "active"
    end

    def steam_uid
      SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
    end

    def minutes_connected
      splitted_time = connect_duration.split(":").map(&:to_i)
      if splitted_time.size == 2
        splitted_time.first
      elsif splitted_time.size == 3
        splitted_time.first * 60 + splitted_time.second
      end
    end

  end

end
