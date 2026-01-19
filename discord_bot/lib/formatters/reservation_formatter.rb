# typed: false
# frozen_string_literal: true

module ServemeBot
  module Formatters
    class ReservationFormatter
      SERVEME_COLOR = 0x5865F2 # Discord blurple
      CURRENT_COLOR = 0x57F287 # Green
      FUTURE_COLOR = 0x5865F2 # Blurple
      PAST_COLOR = 0x99AAB5 # Gray

      class << self
        def format_reservation_list(data, title: "Your Reservations")
          player = data[:player] || data["player"]
          reservations = data[:reservations] || data["reservations"] || []

          return empty_embed(title) if reservations.empty?

          # Take first 10 reservations
          display_reservations = reservations.first(10)

          description = display_reservations.map do |res|
            format_reservation_line(res)
          end.join("\n")

          if reservations.size > 10
            description += "\n\n_...and #{reservations.size - 10} more_"
          end

          embed = {
            title: title,
            description: description,
            color: SERVEME_COLOR,
            footer: { text: SITE_HOST },
            timestamp: Time.now.iso8601
          }

          if player
            embed[:author] = {
              name: player["nickname"],
              url: player["steam_profile_url"]
            }
          end

          embed
        end

        def format_reservation_line(res)
          flag = res["region_flag"] || flag_from_server(res["flag"])
          server_name = res["server_name"] || "Unknown Server"
          time = format_reservation_time(res)
          map = res["first_map"]

          parts = [ flag, "**#{server_name}**" ]
          parts << "`#{map}`" if map && !map.empty?
          parts << "• #{time}"

          parts.reject(&:empty?).join(" ")
        end

        def format_current_reservation(res)
          return nil unless res

          flag = res["region_flag"] || ""
          server_name = res["server_name"]
          ends_at = format_time(res["ends_at"])

          {
            title: "Current Reservation",
            description: "#{flag} **#{server_name}**\nEnds at #{ends_at}",
            color: CURRENT_COLOR,
            footer: { text: SITE_HOST }
          }
        end

        private

        def empty_embed(title)
          {
            title: title,
            description: "No reservations found.",
            color: SERVEME_COLOR
          }
        end

        def status_icon(status)
          case status
          when "current"
            ":green_circle:"
          when "future"
            ":blue_circle:"
          else
            ":white_circle:"
          end
        end

        def flag_from_server(flag)
          return "" unless flag

          flag.upcase.chars.map { |c| (c.ord + 127397).chr("UTF-8") }.join
        end

        def format_reservation_time(res)
          starts_at = Time.parse(res["starts_at"]) rescue nil
          ends_at = Time.parse(res["ends_at"]) rescue nil

          return "Unknown time" unless starts_at

          if res["status"] == "current"
            "Now - ends #{ends_at&.strftime('%H:%M') || '?'}"
          elsif res["status"] == "future"
            "#{starts_at.strftime('%b %d, %H:%M')} - #{ends_at&.strftime('%H:%M') || '?'}"
          else
            starts_at.strftime("%b %d, %Y")
          end
        end

        def format_time(time_string)
          return "?" unless time_string

          time = Time.parse(time_string)
          time.strftime("%H:%M")
        rescue ArgumentError
          "?"
        end
      end
    end
  end
end
