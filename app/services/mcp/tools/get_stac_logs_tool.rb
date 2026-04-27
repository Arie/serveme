# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class GetStacLogsTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "get_stac_logs"
      end

      sig { override.returns(String) }
      def self.description
        "Look up STAC anti-cheat logs and detections for a reservation. " \
        "Returns log file metadata, detection summary per player " \
        "(steam_uid, detection_type, count), and optionally the raw log contents."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            reservation_id: {
              type: "integer",
              description: "The reservation ID to look up STAC logs for"
            },
            include_contents: {
              type: "boolean",
              description: "When true, includes the raw decoded log contents in the response. " \
                          "Default: false (logs can be large).",
              default: false
            }
          },
          required: [ "reservation_id" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :league_admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        reservation_id = params[:reservation_id]
        return { error: "reservation_id is required" } if reservation_id.blank?

        reservation = Reservation.find_by(id: reservation_id)
        return { error: "Reservation ##{reservation_id} not found" } unless reservation

        include_contents = params.fetch(:include_contents, false) == true

        Rails.logger.info("STAC log lookup started by #{user.name} (#{user.uid}) for reservation #{reservation_id}")

        {
          reservation_id: reservation.id,
          stac_logs: reservation.stac_logs.order(:created_at).map { |log| format_log(log, include_contents) },
          detections: StacDetection.where(reservation_id: reservation.id).order(:player_name, :detection_type).map { |d| format_detection(d) }
        }
      end

      private

      sig { params(log: StacLog, include_contents: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def format_log(log, include_contents)
        result = {
          id: log.id,
          filename: log.filename,
          filesize: log.filesize,
          created_at: log.created_at
        }
        result[:contents] = decode_contents(log.contents) if include_contents
        result
      end

      sig { params(detection: StacDetection).returns(T::Hash[Symbol, T.untyped]) }
      def format_detection(detection)
        {
          steam_uid: detection.steam_uid.to_s,
          player_name: detection.player_name,
          steam_id: detection.steam_id,
          detection_type: detection.detection_type,
          count: detection.count,
          stac_log_id: detection.stac_log_id
        }
      end

      sig { params(contents: T.nilable(T.any(String, T.untyped))).returns(T.nilable(String)) }
      def decode_contents(contents)
        return nil if contents.nil?

        contents.to_s.force_encoding("UTF-8").scrub
      end
    end
  end
end
