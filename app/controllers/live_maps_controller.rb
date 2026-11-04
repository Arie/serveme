# typed: true
# frozen_string_literal: true

# The live STV map of any server: signed-in users paste a SourceTV connect string (or an address
# and password), it is checked for an answering SourceTV, and they get sent to the map server
# with a start token (see StvtfToken). A demos.tf link plays that demo on the map instead.
class LiveMapsController < ApplicationController
  before_action :require_admin_or_streamer, only: :index
  # Refreshes and searches only need the frame.
  layout :live_stv_layout

  def new; end

  def index
    matches, @hub_error = StvtfHub.matches
    @watched, @demos = matches.partition { |m| !m.demo? }
    @owner_names = User.where(uid: matches.filter_map { |m| m["owner"] }).pluck(:uid, :nickname).to_h
    @watched_reservations = @watched.select(&:reservation_id).index_by(&:reservation_id)

    rows = LiveStvReservations.rows
    @reservations_by_id = rows.map(&:reservation).index_by(&:id)
    with_players, empty = rows.partition { |row| row.players.any? }
    @reservation_count = with_players.size
    @player_count = with_players.sum { |row| row.players.size }

    @search = LiveStvSearch.new(params[:q])
    show_empty = params[:empty] == "1"
    if @search.active?
      @rows = @search.filter(rows)
      @toggle = [ "Clear search", live_stv_path ]
    else
      @rows = show_empty ? with_players + empty : with_players
      @toggle = show_empty ? [ "Hide empty", live_stv_path ] : [ "Show empty", live_stv_path(empty: 1) ] if empty.any?
    end
  end

  def create
    return redirect_to(live_map_path, alert: "The live map is not available here") unless StvtfToken.enabled?

    input = params[:connect].to_s.first(300)
    redirect_to start_url(input), allow_other_host: true
  rescue StvConnect::Error, DemostfDemo::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

  def live_stv_layout
    request.headers["Turbo-Frame"].present? ? "turbo_rails/frame" : resolve_layout
  end

  def start_url(input)
    if (demo = DemostfDemo.parse(input))
      StvtfToken.start_url(demo: demo.check!.id, owner: current_user&.uid)
    else
      StvtfToken.start_url(connect: StvConnect.parse(input).check!.connect_string, owner: current_user&.uid)
    end
  end
end
