# typed: false
# frozen_string_literal: true

class DiscordController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :callback ]

  # GET /discord
  # Redirects to bot invite URL
  # Permissions: Send Messages (2048), Embed Links (16384)
  BOT_PERMISSIONS = 2048 + 16384

  def invite
    redirect_to "https://discord.com/oauth2/authorize?client_id=#{discord_client_id}&permissions=#{BOT_PERMISSIONS}&scope=bot", allow_other_host: true
  end

  # GET /discord/link
  # Redirects to Discord OAuth2 authorization
  def link
    state = SecureRandom.hex(16)
    Rails.cache.write("discord_link_state:#{state}", { created_at: Time.current }, expires_in: 10.minutes)

    oauth_url = discord_oauth_url(state)
    redirect_to oauth_url, allow_other_host: true
  end

  # GET /discord/callback
  # Handles OAuth2 callback from Discord
  def callback
    state = params[:state]
    code = params[:code]
    error = params[:error]

    if error
      return render plain: "Authorization denied: #{params[:error_description]}", status: :forbidden
    end

    unless state && Rails.cache.read("discord_link_state:#{state}")
      return render plain: "Invalid or expired state. Please try again.", status: :bad_request
    end

    Rails.cache.delete("discord_link_state:#{state}")

    # Exchange code for access token
    token_response = exchange_code_for_token(code)
    unless token_response
      return render plain: "Failed to get access token from Discord.", status: :bad_gateway
    end

    access_token = token_response["access_token"]

    # Get user info and connections
    discord_user = fetch_discord_user(access_token)
    connections = fetch_discord_connections(access_token)

    unless discord_user
      return render plain: "Failed to get Discord user info.", status: :bad_gateway
    end

    steam_connection = connections&.find { |c| c["type"] == "steam" }
    unless steam_connection
      return render plain: "No Steam account linked to your Discord. Please link Steam in Discord Settings > Connections first.", status: :unprocessable_entity
    end

    discord_uid = discord_user["id"]
    steam_uid = steam_connection["id"]

    # Find serveme user by Steam ID
    user = User.find_by(uid: steam_uid)
    unless user
      return render plain: "No serveme.tf account found for Steam ID #{steam_uid}. Please create a reservation first to create your account.", status: :not_found
    end

    # Check if Discord is already linked to another user
    existing_link = User.where(discord_uid: discord_uid).where.not(id: user.id).first
    if existing_link
      return render plain: "This Discord account is already linked to another serveme.tf user (#{existing_link.nickname}).", status: :conflict
    end

    # Link the accounts
    user.update!(discord_uid: discord_uid)

    render plain: "Success! Your Discord account (#{discord_user['username']}) is now linked to #{user.nickname} on #{SITE_HOST}.\n\nYou can close this window and use /#{discord_command_name} in Discord."
  end

  private

  def discord_oauth_url(state)
    params = {
      client_id: discord_client_id,
      redirect_uri: discord_callback_url,
      response_type: "code",
      scope: "identify connections",
      state: state
    }

    "https://discord.com/api/oauth2/authorize?#{params.to_query}"
  end

  def exchange_code_for_token(code)
    uri = URI.parse("https://discord.com/api/oauth2/token")

    response = Net::HTTP.post_form(uri, {
      client_id: discord_client_id,
      client_secret: discord_client_secret,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: discord_callback_url
    })

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Discord token exchange failed: #{e.message}")
    nil
  end

  def fetch_discord_user(access_token)
    fetch_discord_api("/users/@me", access_token)
  end

  def fetch_discord_connections(access_token)
    fetch_discord_api("/users/@me/connections", access_token)
  end

  def fetch_discord_api(endpoint, access_token)
    uri = URI.parse("https://discord.com/api#{endpoint}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Discord API request failed: #{e.message}")
    nil
  end

  def discord_client_id
    Rails.application.credentials.dig(:discord, :"#{region_key}_client_id")
  end

  def discord_client_secret
    Rails.application.credentials.dig(:discord, :"#{region_key}_client_secret")
  end

  def region_key
    case SITE_URL
    when /na\.serveme\.tf/ then "na"
    when /sea\.serveme\.tf/ then "sea"
    when /au\.serveme\.tf/ then "au"
    else "eu"
    end
  end

  def discord_command_name
    region_key == "eu" ? "serveme" : "serveme-#{region_key}"
  end

  def discord_callback_url
    "#{request.base_url}/discord/callback"
  end
end
