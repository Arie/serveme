# typed: false
# frozen_string_literal: true

class LogStreamingService
  DEFAULT_CHUNK_SIZE = 1_000
  MAX_CHUNK_SIZE = 5_000

  attr_reader :filename, :search_query, :offset, :chunk_size

  def initialize(filename, search_query: nil, offset: 0, chunk_size: DEFAULT_CHUNK_SIZE)
    @filename = filename
    @search_query = search_query
    @offset = offset
    @chunk_size = [ chunk_size, MAX_CHUNK_SIZE ].min
  end

  # Stream lines in forward order (oldest first) - used for streaming view
  def stream_forward
    search_term = search_query&.downcase

    if search_term.present?
      stream_forward_with_search(search_term)
    else
      stream_forward_without_search
    end
  end

  # Stream lines in reverse order (newest first) - used for rcon view
  def stream_reverse
    search_term = search_query&.downcase

    if search_term.present?
      stream_reverse_with_search(search_term)
    else
      stream_reverse_without_search
    end
  end

  private

  def stream_forward_with_search(search_term)
    total_lines = count_lines_fast
    all_matches = search_with_ripgrep(search_term)

    page = all_matches.slice(offset, chunk_size) || []
    lines = page.map { |match| StringSanitizer.tidy_bytes(match[:content]) }

    build_result(
      lines: lines,
      total_lines: total_lines,
      matched_lines: all_matches.size,
      has_more: (offset + chunk_size) < all_matches.size,
      loaded_lines: [ offset + lines.size, all_matches.size ].min
    )
  end

  def stream_forward_without_search
    total_lines = count_lines_fast
    needed_end = offset + chunk_size
    lines = []
    current_line = 0

    File.foreach(filename) do |line|
      if current_line >= offset && current_line < needed_end
        lines << StringSanitizer.tidy_bytes(line)
      end
      current_line += 1
      break if current_line >= needed_end
    end

    build_result(
      lines: lines,
      total_lines: total_lines,
      matched_lines: total_lines,
      has_more: needed_end < total_lines,
      loaded_lines: [ offset + lines.size, total_lines ].min
    )
  end

  def stream_reverse_with_search(search_term)
    total_lines = count_lines_fast
    all_matches = search_with_ripgrep(search_term)

    reversed_matches = all_matches.reverse
    page = reversed_matches.slice(offset, chunk_size) || []
    lines = page.map { |match| StringSanitizer.tidy_bytes(match[:content]) }

    build_result(
      lines: lines,
      total_lines: total_lines,
      matched_lines: all_matches.size,
      has_more: (offset + chunk_size) < all_matches.size,
      loaded_lines: [ offset + lines.size, all_matches.size ].min
    )
  end

  def stream_reverse_without_search
    total_lines = count_lines_fast

    start_idx = [ total_lines - offset - chunk_size, 0 ].max
    end_idx = total_lines - offset

    lines = []
    current_line = 0

    File.foreach(filename) do |line|
      if current_line >= start_idx && current_line < end_idx
        lines << StringSanitizer.tidy_bytes(line)
      end
      current_line += 1
      break if current_line >= end_idx
    end

    lines.reverse!

    build_result(
      lines: lines,
      total_lines: total_lines,
      matched_lines: total_lines,
      has_more: (offset + chunk_size) < total_lines,
      loaded_lines: [ offset + lines.size, total_lines ].min
    )
  end

  def search_with_ripgrep(search_term)
    sanitized_term = sanitize_search_term(search_term)
    return [] if sanitized_term.blank?

    matches = []

    IO.popen([ "rg", "--line-number", "--ignore-case", "--fixed-strings", sanitized_term, filename.to_s ]) do |io|
      io.each_line do |line|
        line_number, content = line.split(":", 2)
        matches << { line_number: line_number.to_i - 1, content: content }
      end
    end

    matches
  end

  def sanitize_search_term(term)
    return nil if term.nil?

    term = term[0, 200]

    term.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  end

  def count_lines_fast
    return 0 unless File.exist?(filename)

    count = 0
    File.open(filename, "rb") do |f|
      while (chunk = f.read(1_048_576)) # 1MB chunks
        count += chunk.count("\n")
      end
    end
    count
  end

  def build_result(lines:, total_lines:, matched_lines:, has_more:, loaded_lines:)
    {
      lines: lines,
      total_lines: total_lines,
      matched_lines: matched_lines,
      has_more: has_more,
      loaded_lines: loaded_lines,
      next_offset: offset + chunk_size
    }
  end
end
