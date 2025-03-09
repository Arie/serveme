# typed: false
# frozen_string_literal: true

class StacDiscordNotifier
  def initialize(reservation)
    @reservation = reservation
  end

  def notify(detections)
    return if detections.empty?

    filtered_detections = detections.transform_values do |data|
      detection_counts = data[:detections].tally
      filtered_detections = data[:detections].reject do |detection|
        (detection.match?(/Silent ?Aim/i) || detection.match?(/Trigger ?Bot/i) || detection == 'CmdNum SPIKE' || detection == 'Aimsnap') &&
          detection_counts[detection] < 3
      end

      data.merge(detections: filtered_detections)
    end.reject { |_, data| data[:detections].empty? }

    return if filtered_detections.empty?

    description = [
      "Server: [#{@reservation.server.name} (##{@reservation.id})](#{SITE_URL}/reservations/#{@reservation.id})",
      "[View STAC Log](#{SITE_URL}/reservations/#{@reservation.id}/stac_log)"
    ]

    payload = {
      embeds: [{
        title: 'StAC Detection Report',
        description: description.join("\n"),
        color: 0xFF0000,
        fields: filtered_detections.map do |steam_id64, data|
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
