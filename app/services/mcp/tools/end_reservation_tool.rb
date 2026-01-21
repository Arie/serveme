# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class EndReservationTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "end_reservation"
      end

      sig { override.returns(String) }
      def self.description
        "End an active reservation early. The reservation must be currently running " \
        "(not scheduled for the future or already ended). Requires authorization via " \
        "Steam ID or linked Discord account."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            reservation_id: {
              type: "integer",
              description: "The reservation ID to end"
            },
            steam_uid: {
              type: "string",
              description: "Steam ID64 of the reservation owner (for authorization)"
            },
            discord_uid: {
              type: "string",
              description: "Discord user ID (for authorization via linked account)"
            }
          },
          required: [ "reservation_id" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        reservation_id = params[:reservation_id]
        return { error: "reservation_id is required" } unless reservation_id

        reservation = Reservation.find_by(id: reservation_id)
        return { error: "Reservation not found" } unless reservation

        # Verify the requesting user owns this reservation
        owner_result = verify_owner(reservation, params)
        return owner_result if owner_result[:error]

        # Check if reservation can be ended
        endable_result = check_endable(reservation)
        return endable_result if endable_result[:error]

        # End the reservation
        begin
          reservation.end_reservation
          format_ended_reservation(reservation)
        rescue StandardError => e
          { error: "Failed to end reservation: #{e.message}" }
        end
      end

      private

      sig { params(reservation: Reservation, params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def verify_owner(reservation, params)
        if params[:discord_uid].present?
          user = User.find_by(discord_uid: params[:discord_uid])
          return { error: "Discord account not linked" } unless user
          return { error: "Not authorized to end this reservation" } unless reservation.user_id == user.id
        elsif params[:steam_uid].present?
          return { error: "Not authorized to end this reservation" } unless reservation.user&.uid == params[:steam_uid]
        else
          return { error: "Either steam_uid or discord_uid is required for authorization" }
        end
        {}
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def check_endable(reservation)
        if reservation.ended?
          return { error: "Reservation has already ended" }
        end

        if reservation.future?
          return {
            error: "Cannot end a future reservation. Use the website to cancel scheduled reservations.",
            hint: "Reservation is scheduled to start at #{reservation.starts_at&.iso8601}"
          }
        end

        unless reservation.now?
          return { error: "Reservation is not currently active" }
        end

        {}
      end

      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def format_ended_reservation(reservation)
        server = reservation.server

        {
          success: true,
          message: "Reservation ended successfully",
          reservation: {
            id: reservation.id,
            server_name: server&.name,
            started_at: reservation.starts_at&.iso8601,
            ended_at: Time.current.iso8601,
            status: "ending"
          }
        }
      end
    end
  end
end
