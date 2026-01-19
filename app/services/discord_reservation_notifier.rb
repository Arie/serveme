# typed: false
# frozen_string_literal: true

class DiscordReservationNotifier
  # Flag mappings for Discord emoji
  FLAG_MAPPINGS = {
    "uk" => "gb",
    "en" => "england",
    "scotland" => "scotland",
    "europeanunion" => "eu"
  }.freeze

  def initialize(reservation)
    @reservation = reservation
    @server = reservation.server
  end

  def update
    return unless tracking?

    # Skip if nothing visible has changed
    new_state = compute_state_hash
    cache_key = "discord_embed_state:#{@reservation.id}"
    old_state = Rails.cache.read(cache_key)

    if old_state == new_state
      Rails.logger.debug "Discord update skipped for reservation #{@reservation.id} - no visible changes"
      return
    end

    embed = build_embed
    components = build_components

    DiscordApiClient.update_message(
      channel_id: @reservation.discord_channel_id,
      message_id: @reservation.discord_message_id,
      embed: embed,
      components: components
    )

    Rails.cache.write(cache_key, new_state, expires_in: 3.hours)

    # Clear Discord info and cache after reservation ends
    if @reservation.ended?
      Rails.cache.delete(cache_key)
      @reservation.update_columns(discord_channel_id: nil, discord_message_id: nil)
    end
  rescue DiscordApiClient::RateLimitError => e
    # Re-raise to let Sidekiq retry
    raise e
  rescue DiscordApiClient::ApiError => e
    Rails.logger.error "Discord update failed for reservation #{@reservation.id}: #{e.message}"
    # Don't retry on other API errors (message deleted, etc.)
  end

  def tracking?
    @reservation.discord_channel_id.present? && @reservation.discord_message_id.present?
  end

  private

  def compute_state_hash
    # Capture all dynamic fields that appear in the embed
    # Static fields (server name, config, whitelist, connect strings) don't need tracking
    {
      status: reservation_status,
      status_message: latest_status_message,
      map: current_map,
      players: player_count,
      ends_at: @reservation.ends_at.to_i,
      ended: @reservation.ended?
    }.hash
  end

  def build_embed
    status = reservation_status

    {
      title: "#{flag_emoji} #{@server.name}",
      color: status_color(status),
      fields: build_fields(status),
      footer: { text: "Reservation ##{@reservation.id}" },
      timestamp: Time.current.iso8601
    }
  end

  def build_fields(status)
    config_name = @reservation.server_config&.file || "None"
    whitelist_name = @reservation.whitelist&.file || @reservation.custom_whitelist_id || "None"

    fields = [
      { name: "Status", value: status_text(status), inline: true },
      { name: "Map", value: current_map, inline: true },
      { name: "Players", value: "#{player_count}/24", inline: true },
      { name: "Ends", value: @reservation.ended? ? "Ended" : "<t:#{@reservation.ends_at.to_i}:R>", inline: true },
      { name: "Config", value: config_name, inline: true },
      { name: "Whitelist", value: whitelist_name, inline: true }
    ]

    unless @reservation.ended?
      connect_string = @server.server_connect_string(@reservation.password)
      stv_connect_string = @server.stv_connect_string(@reservation.tv_password)
      fields << { name: "Connect", value: "```#{connect_string}```", inline: false }
      fields << { name: "Password", value: "`#{@reservation.password}`", inline: true }
      fields << { name: "STV", value: "```#{stv_connect_string}```", inline: false }
    end

    fields
  end

  def build_components
    if @reservation.ended?
      # Show Logs & Demos link - direct to zip file
      [ {
        type: 1, # Action row
        components: [ {
          type: 2, # Button
          style: 5, # Link
          label: "Logs & Demos",
          url: @reservation.zipfile_url
        } ]
      } ]
    else
      # Show End, Extend, RCON buttons
      [ {
        type: 1,
        components: [
          {
            type: 2,
            style: 4, # Danger (red)
            label: "End",
            custom_id: "end_reservation:#{@reservation.id}"
          },
          {
            type: 2,
            style: 1, # Primary (blue)
            label: "Extend",
            custom_id: "extend_reservation:#{@reservation.id}"
          },
          {
            type: 2,
            style: 5, # Link
            label: "RCON",
            url: "#{SITE_URL}/reservations/#{@reservation.id}/rcon"
          }
        ]
      } ]
    end
  end

  def reservation_status
    if @reservation.ended?
      "ended"
    elsif @reservation.provisioned? && @reservation.now?
      "ready"
    elsif @reservation.now?
      "starting"
    elsif @reservation.future?
      "scheduled"
    else
      "past"
    end
  end

  def status_color(status)
    case status
    when "ready" then 0x57F287    # Green
    when "starting" then 0xFEE75C # Yellow
    when "ended" then 0x99AAB5    # Gray
    else 0x5865F2                 # Blue
    end
  end

  def status_text(status)
    case status
    when "ready" then ":green_circle: Server Ready"
    when "starting" then ":yellow_circle: #{latest_status_message}"
    when "ended" then ":white_circle: Ended"
    else ":blue_circle: #{status.capitalize}"
    end
  end

  def latest_status_message
    latest = ReservationStatus.where(reservation_id: @reservation.id)
                              .order(created_at: :desc)
                              .first
    latest&.status.presence || "Starting..."
  end

  def current_map
    latest_server_stat&.map_name.presence || @reservation.first_map
  end

  def player_count
    latest_server_stat&.number_of_players || 0
  end

  def latest_server_stat
    @latest_server_stat ||= ServerStatistic.where(reservation_id: @reservation.id)
                                           .order(created_at: :desc)
                                           .first
  end

  def flag_emoji
    flag_code = @server.location_flag
    return ":globe_with_meridians:" if flag_code.nil? || flag_code.to_s.strip.empty?

    code = flag_code.to_s.downcase
    mapped = FLAG_MAPPINGS[code] || code

    case mapped
    when "england" then ":england:"
    when "scotland" then ":scotland:"
    else ":flag_#{mapped}:"
    end
  end
end
