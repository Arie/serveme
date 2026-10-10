# typed: true
# frozen_string_literal: true

class ChatCommandSuggester
  extend T::Sig

  COMMANDS = %w[end extend rcon sdr webrcon timeleft who whois lock unlock unbanall password help stv].freeze

  # Chat commands of other plugins (TF2Center, MGE, logs.tf, ...) that sit within typo distance of ours.
  OTHER_PLUGIN_COMMANDS = %w[add log logs rep remove ready rtd rtv ss r demo stats].freeze

  sig { params(message: String).returns(T.nilable(String)) }
  def self.suggest(message)
    word = message[/\A!(\w+)\z/, 1]&.downcase
    return if word.nil? || word.length < 3 || COMMANDS.include?(word) || OTHER_PLUGIN_COMMANDS.include?(word)

    match = COMMANDS.min_by { |command| distance(word, command) }
    "!#{match}" if match && distance(word, match) <= (match.length <= 5 ? 1 : 2)
  end

  # Optimal string alignment distance: Levenshtein plus adjacent transpositions, so "extned" is one edit from "extend".
  sig { params(a: String, b: String).returns(Integer) }
  def self.distance(a, b)
    d = Array.new(a.length + 1) { |i| Array.new(b.length + 1) { |j| i.zero? ? j : (j.zero? ? i : 0) } }
    (1..a.length).each do |i|
      (1..b.length).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        d[i][j] = [ d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost ].min
        d[i][j] = [ d[i][j], d[i - 2][j - 2] + 1 ].min if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]
      end
    end
    d[a.length][b.length]
  end
end
