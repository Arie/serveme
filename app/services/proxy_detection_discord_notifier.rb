# typed: false
# frozen_string_literal: true

class ProxyDetectionDiscordNotifier
  MAX_EMBED_FIELDS = 25

  def notify(player_data)
    return if player_data.empty?

    payload = {
      embeds: [ {
        title: "Daily Proxy Detection Report for #{SITE_HOST}",
        description: "#{Date.yesterday.iso8601} — #{player_data.size} player(s) detected",
        color: 0xFFA500,
        fields: build_fields(player_data),
        timestamp: Time.now.iso8601
      } ]
    }

    send_to_discord(payload)
  end

  private

  def build_fields(player_data)
    fields = player_data.first(MAX_EMBED_FIELDS).map do |steam_uid, data|
      ip_lines = data[:ips].map do |ip, ip_info|
        res_links = ip_info[:reservation_ids].map { |rid| "[##{rid}](#{SITE_URL}/reservations/#{rid})" }.join(", ")
        "• #{ip} (score: #{ip_info[:fraud_score]}, #{ip_info[:isp]}, #{ip_info[:country_code]}) — #{res_links}"
      end

      {
        name: data[:name],
        value: [
          "SteamID: [#{steam_uid}](#{SITE_URL}/league-request?steam_uid=#{steam_uid}&cross_reference=true)",
          *ip_lines
        ].join("\n").truncate(1024),
        inline: false
      }
    end

    if player_data.size > MAX_EMBED_FIELDS
      fields << {
        name: "...",
        value: "#{player_data.size - MAX_EMBED_FIELDS} more player(s) not shown",
        inline: false
      }
    end

    fields
  end

  def send_to_discord(payload)
    uri = URI.parse(Rails.application.credentials.discord[:stac_webhook_url])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(
      uri.path,
      "Content-Type" => "application/json"
    )
    request.body = payload.to_json

    http.request(request)
  end
end
