# typed: true
# frozen_string_literal: true

class LiveStvSearch
  extend T::Sig

  sig { params(query: T.nilable(String)).void }
  def initialize(query)
    @query = query.to_s.strip.first(100)
  end

  sig { returns(String) }
  attr_reader :query

  sig { returns(T::Boolean) }
  def active?
    @query.present?
  end

  sig { params(row: LiveStvReservations::Row).returns(T::Boolean) }
  def match?(row)
    owner = row.reservation.user
    if (uid = steam_uid)
      owner&.uid == uid || row.players.any? { |p| p.steam_uid == uid }
    else
      needle = @query.downcase
      [ owner&.nickname, *row.players.map(&:name) ].compact.any? { |name| name.downcase.include?(needle) }
    end
  end

  private

  sig { returns(T.nilable(String)) }
  def steam_uid
    return @steam_uid if defined?(@steam_uid)

    @steam_uid =
      if @query.match?(/\A\d{17}\z/)
        @query
      elsif @query.match?(/\ASTEAM_[0-5]:[01]:\d+\z/i) || @query.match?(/\A\[U:1:\d+\]\z/i)
        begin
          SteamCondenser::Community::SteamId.steam_id_to_community_id(@query).to_s
        rescue StandardError
          nil
        end
      end
  end
end
