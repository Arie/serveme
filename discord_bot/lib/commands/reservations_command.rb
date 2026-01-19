# typed: false
# frozen_string_literal: true

module ServemeBot
  module Commands
    class ReservationsCommand < BaseCommand
      def execute(status: nil, limit: 10)
        log_command("reservations", status: status, limit: limit)
        return unless require_linked_account!

        defer_response

        reservations = fetch_user_reservations(status, limit.to_i)

        if reservations.empty?
          return edit_response(content: ":information_source: No reservations found for **#{current_user.nickname}**.")
        end

        result = {
          player: { nickname: current_user.nickname, steam_uid: current_user.uid },
          reservations: reservations,
          total_count: reservations.size
        }

        embed = Formatters::ReservationFormatter.format_reservation_list(
          result,
          title: build_title(status)
        )

        edit_response(embeds: [ embed ])
      rescue StandardError => e
        Rails.logger.error "ReservationsCommand error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        edit_response(content: ":x: Failed to fetch reservations. Please try again later.")
      end

      private

      def fetch_user_reservations(status, limit)
        scope = current_user.reservations.includes(:server).order(starts_at: :desc)

        case status
        when "current"
          scope = scope.where("starts_at <= ? AND ends_at >= ? AND ended = ?", Time.current, Time.current, false)
        when "future"
          scope = scope.where("starts_at > ?", Time.current)
        when "past"
          scope = scope.where("ended = ? OR ends_at < ?", true, Time.current)
        end

        scope.limit(limit).map do |reservation|
          format_reservation(reservation)
        end
      end

      def format_reservation(reservation)
        server = reservation.server

        status_string = if reservation.ended?
                          "ended"
        elsif reservation.now?
                          "active"
        elsif reservation.future?
                          "scheduled"
        else
                          "past"
        end

        {
          "id" => reservation.id,
          "server_name" => server&.name,
          "server_ip" => server&.ip,
          "server_port" => server&.port,
          "status" => status_string,
          "starts_at" => reservation.starts_at&.iso8601,
          "ends_at" => reservation.ends_at&.iso8601,
          "first_map" => reservation.first_map,
          "password" => reservation.password,
          "connect_string" => "connect #{server&.ip}:#{server&.port}; password #{reservation.password}"
        }
      end

      def build_title(status)
        case status
        when "current"
          "Your Current Reservations"
        when "future"
          "Your Upcoming Reservations"
        when "past"
          "Your Past Reservations"
        else
          "Your Reservations"
        end
      end
    end
  end
end
