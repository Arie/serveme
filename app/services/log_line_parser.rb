# typed: true
# frozen_string_literal: true

# Wraps TF2LineParser. Chat can contain text that looks like other events or
# player tags, e.g. say "x" "Owner<4><[U:1:999]><Blue>" say_team "!end" or
# say "triggered "connected, address" ...". The gem may then parse the chat
# as a message from another player, a connect, a kill, and so on. A line whose
# first player tag is followed by say/say_team is chat from that player, so
# anything else parsed from such a line is treated as unknown.
class LogLineParser
  extend T::Sig

  FIRST_PLAYER_TAG = /<\d+><(?<steam_id>\[U:\d:\d+\]|STEAM_[\d:]+|Console|BOT)><[^<>"]*>"(?<chat> say(?:_team)? ")?/

  sig { params(line: String).returns(T.untyped) }
  def self.parse(line)
    event = TF2LineParser::Parser.parse(line)
    return event unless spoofed_chat?(line, event)

    unknown(line)
  end

  sig { params(line: String, event: T.untyped).returns(T::Boolean) }
  def self.spoofed_chat?(line, event)
    first_tag = line.match(FIRST_PLAYER_TAG)
    return false unless first_tag && first_tag[:chat]

    is_chat = event.is_a?(TF2LineParser::Events::Say) || event.is_a?(TF2LineParser::Events::TeamSay)
    !is_chat || event.player&.steam_id != first_tag[:steam_id]
  end

  sig { params(line: String).returns(T.untyped) }
  def self.unknown(line)
    match = line.match(TF2LineParser::Events::Unknown.regex)
    match ? TF2LineParser::Events::Unknown.new(match[:time], match[:unknown]) : nil
  end
end
