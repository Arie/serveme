# typed: true
# frozen_string_literal: true

# Players as this region's league knows them, for the live STV map (stvtf-web): each one's name
# there and the teams they are on. From the profiles kept a day (Etf2lApi, RglApi, OzfortressApi).
class LeagueRoster
  extend T::Sig

  LEAGUES = T.let({
    "serveme.tf" => "ETF2L",
    "na.serveme.tf" => "RGL",
    "au.serveme.tf" => "ozfortress"
  }.freeze, T::Hash[String, String])
  # The most players asked about at once, and the most asked of the league at a time.
  MAX_PLAYERS = 40
  THREADS = 4

  sig { returns(T.nilable(String)) }
  def self.league
    LEAGUES[SITE_HOST]
  end

  sig { params(steam_uids: T::Array[String]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def self.players(steam_uids)
    league = self.league
    return [] unless league

    queue = Thread::Queue.new(steam_uids.uniq.first(MAX_PLAYERS))
    queue.close
    found = Thread::Queue.new
    Array.new(THREADS) do
      Thread.new do
        while (uid = queue.pop)
          known = player(league, uid)
          found << known if known
        end
      end
    end.each(&:join)
    Array.new(found.size) { found.pop }.sort_by { |p| p[:steam_uid] }
  end

  sig { params(league: String, steam_uid: String).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def self.player(league, steam_uid)
    json = JSON.parse(profile(league, steam_uid).presence || "{}")
    name, teams = send(:"#{league.downcase}_player", json)
    { steam_uid: steam_uid, name: name, teams: teams } if name.present?
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  sig { params(league: String, steam_uid: String).returns(T.nilable(String)) }
  def self.profile(league, steam_uid)
    case league
    when "ETF2L" then Etf2lApi.profile(steam_uid)
    when "RGL" then RglApi.profile(steam_uid)
    else OzfortressApi.profile(steam_uid)
    end
  end

  sig { params(json: T.untyped).returns([ T.untyped, T::Array[T::Hash[Symbol, T.untyped]] ]) }
  def self.etf2l_player(json)
    teams = Array(json.dig("player", "teams")).map { |t| { name: t["name"], tag: t["tag"], format: t["type"] } }
    [ json.dig("player", "name"), teams ]
  end

  # `currentTeams` is by format: sixes, highlander, prolander; none where they have no team.
  sig { params(json: T.untyped).returns([ T.untyped, T::Array[T::Hash[Symbol, T.untyped]] ]) }
  def self.rgl_player(json)
    current = json["currentTeams"]
    teams = (current.is_a?(Hash) ? current : {}).filter_map do |format, t|
      { name: t["name"], tag: t["tag"], format: format } if t.is_a?(Hash)
    end
    [ json["name"], teams ]
  end

  sig { params(json: T.untyped).returns([ T.untyped, T::Array[T::Hash[Symbol, T.untyped]] ]) }
  def self.ozfortress_player(json)
    rosters = Array(json.dig("user", "rosters")).reject { |r| r["disbanded"] }
    [ json.dig("user", "name"), rosters.map { |r| { name: r["name"], tag: nil, format: nil } } ]
  end
  private_class_method :player, :profile, :etf2l_player, :rgl_player, :ozfortress_player
end
