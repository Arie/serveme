# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class SearchReservationLogsTool < BaseTool
      extend T::Sig

      MAX_SEARCH_TERM_LENGTH = 200

      sig { override.returns(String) }
      def self.tool_name
        "search_reservation_logs"
      end

      sig { override.returns(String) }
      def self.description
        "Search through a reservation's log file using ripgrep, or retrieve the log contents. " \
        "Useful for investigating players, finding chat messages, connection events, or any text in server logs."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            reservation_id: {
              type: "integer",
              description: "The reservation ID to search logs for"
            },
            search_term: {
              type: "string",
              description: "Text to search for in the log file (case-insensitive, fixed-string match). " \
                          "If omitted, returns the last lines of the log file."
            },
            context_lines: {
              type: "integer",
              description: "Number of context lines to show around each match (default: 0)",
              default: 0
            },
            max_results: {
              type: "integer",
              description: "Maximum number of lines to return (default: 200)",
              default: 200
            },
            offset: {
              type: "integer",
              description: "Number of matches to skip before returning results (for pagination, default: 0)",
              default: 0
            }
          },
          required: [ "reservation_id" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        reservation_id = params[:reservation_id]
        return { error: "reservation_id is required" } if reservation_id.blank?

        reservation = Reservation.find_by(id: reservation_id)
        return { error: "Reservation ##{reservation_id} not found" } unless reservation

        log_file = log_file_path(reservation)
        return { error: "No log file found for reservation ##{reservation_id}" } unless log_file && File.exist?(log_file)

        search_term = params[:search_term]&.to_s&.presence
        context_lines = [ params.fetch(:context_lines, 0).to_i, 10 ].min
        max_results = [ params.fetch(:max_results, 200).to_i, 1000 ].min
        offset = [ params.fetch(:offset, 0).to_i, 0 ].max

        total_lines = count_lines(log_file)

        if search_term
          search_log(log_file, search_term, context_lines, max_results, offset, reservation_id, total_lines)
        else
          tail_log(log_file, max_results, offset, reservation_id, total_lines)
        end
      end

      private

      sig { params(reservation: Reservation).returns(T.nilable(String)) }
      def log_file_path(reservation)
        return nil if reservation.logsecret.blank?

        path = Rails.root.join("log", "streaming", "#{reservation.logsecret}.log").to_s
        File.exist?(path) ? path : nil
      end

      sig { params(log_file: String).returns(Integer) }
      def count_lines(log_file)
        count = 0
        File.open(log_file, "rb") do |f|
          while (chunk = f.read(1_048_576))
            count += chunk.count("\n")
          end
        end
        count
      end

      sig { params(log_file: String, search_term: String, context_lines: Integer, max_results: Integer, offset: Integer, reservation_id: T.untyped, total_lines: Integer).returns(T::Hash[Symbol, T.untyped]) }
      def search_log(log_file, search_term, context_lines, max_results, offset, reservation_id, total_lines)
        sanitized_term = sanitize_search_term(search_term)
        return { error: "Invalid search term" } if sanitized_term.blank?

        args = [ "rg", "--line-number", "--ignore-case", "--fixed-strings" ]
        args += [ "-C", context_lines.to_s ] if context_lines > 0
        args += [ sanitized_term, log_file ]

        lines = []
        skipped = 0
        IO.popen(args) do |io|
          io.each_line do |line|
            if skipped < offset
              skipped += 1
            else
              lines << line.chomp
              break if lines.size >= max_results
            end
          end
        end

        {
          reservation_id: reservation_id,
          log_file: File.basename(log_file),
          total_lines: total_lines,
          offset: offset,
          match_count: lines.size,
          truncated: lines.size >= max_results,
          lines: lines
        }
      end

      sig { params(log_file: String, max_results: Integer, offset: Integer, reservation_id: T.untyped, total_lines: Integer).returns(T::Hash[Symbol, T.untyped]) }
      def tail_log(log_file, max_results, offset, reservation_id, total_lines)
        all_lines = File.readlines(log_file).map(&:chomp)
        if offset > 0
          lines = all_lines.drop(offset).first(max_results)
        else
          lines = all_lines.last(max_results)
        end

        {
          reservation_id: reservation_id,
          log_file: File.basename(log_file),
          total_lines: total_lines,
          offset: offset,
          lines: lines,
          truncated: offset > 0 ? (offset + lines.size < all_lines.size) : (all_lines.size > max_results)
        }
      end

      sig { params(term: String).returns(T.nilable(String)) }
      def sanitize_search_term(term)
        term = term[0, MAX_SEARCH_TERM_LENGTH]
        T.must(term).encode("UTF-8", invalid: :replace, undef: :replace, replace: "").presence
      end
    end
  end
end
