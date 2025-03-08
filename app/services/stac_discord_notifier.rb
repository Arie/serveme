# typed: false
# frozen_string_literal: true

class StacDiscordNotifier
  def initialize(reservation)
    @reservation = reservation
  end

  def notify(detections)
    return if detections.empty?

    description = [
      "Server: [#{@reservation.server.name} (##{@reservation.id})](#{SITE_URL}/reservations/#{@reservation.id})",
      "[View STAC Log](#{SITE_URL}/reservations/#{@reservation.id}/stac_log)"
    ]

    payload = {
      embeds: [{
        title: 'StAC Detection Report',
        description: description.join("\n"),
        color: 0xFF0000,
        fields: detections.map do |steam_id64, data|
          {
            name: data[:name],
            value: [
              "SteamID: [#{steam_id64}](#{SITE_URL}/league-request?steam_uid=#{steam_id64}&cross_reference=true)",
              "Detections:\n#{data[:detections].tally.map { |type, count| "• #{type}: #{count}x" }.join("\n")}"
            ].join("\n"),
            inline: false
          }
        end,
        timestamp: Time.now.iso8601
      }]
    }

    send_to_discord(payload)
  end

  private

  def send_to_discord(payload)
    uri = URI.parse(Rails.application.credentials.discord[:stac_webhook_url])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(
      uri.path,
      'Content-Type' => 'application/json'
    )
    request.body = payload.to_json

    http.request(request)
  end
end
