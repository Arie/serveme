# typed: true
# frozen_string_literal: true

module Api
  class LiveMapsController < Api::ApplicationController
    before_action :require_admin_or_streamer, only: :index

    # Listed so fields the hub adds later aren't published by accident.
    MATCH_FIELDS = %w[id reservation demo pinned owner server map hostname round round_time time_left match_time win_limit
                      score watching_for viewers peak views done data_age].freeze

    def index
      matches, error = StvtfHub.matches
      render json: { stv_tf: { error: error, matches: matches.map { |m| match_json(m) } },
                     reservations: LiveStvReservations.rows.map { |row| reservation_json(row) } }
    end

    def create
      return render_stv_unavailable unless StvtfToken.enabled?

      input = params.require(:connect).to_s.first(300)
      if (demo = DemostfDemo.parse(input))
        render_stv_link(demo: demo.check!.id)
      else
        render_stv_link(connect: StvConnect.parse(input).check!.connect_string)
      end
    rescue StvConnect::Error, DemostfDemo::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def match_json(match)
      players = Array(match["players"]).map { |p| p.slice("name", "steamid", "team", "class") }
      match.data.slice(*MATCH_FIELDS).merge("players" => players, "url" => match.url, "overlay_url" => match.overlay_url)
    end

    def reservation_json(row)
      reservation = row.reservation
      {
        id: reservation.id,
        server: reservation.server&.name,
        steam_uid: reservation.user&.uid,
        starts_at: reservation.starts_at,
        ends_at: reservation.ends_at,
        map: row.map,
        server_config: reservation.server_config&.to_s,
        whitelist: reservation.whitelist&.to_s,
        players: row.players.map { |p| { name: p.name, steam_uid: p.steam_uid, country_code: p.country_code } }
      }
    end
  end
end
