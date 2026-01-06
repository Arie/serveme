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
    match_indices = []
    total_lines = 0

    File.foreach(filename) do |line|
      match_indices << total_lines if line.downcase.include?(search_term)
      total_lines += 1
    end

    indices_to_fetch = match_indices.slice(offset, chunk_size) || []
    lines = fetch_lines_by_indices(indices_to_fetch)

    build_result(
      lines: lines,
      total_lines: total_lines,
      matched_lines: match_indices.size,
      has_more: (offset + chunk_size) < match_indices.size,
      loaded_lines: [ offset + lines.size, match_indices.size ].min
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
    match_indices = []
    total_lines = 0

    File.foreach(filename) do |line|
      match_indices << total_lines if line.downcase.include?(search_term)
      total_lines += 1
    end

    reversed_matches = match_indices.reverse
    indices_to_fetch = reversed_matches.slice(offset, chunk_size) || []
    lines = fetch_lines_by_indices(indices_to_fetch)

    build_result(
      lines: lines,
      total_lines: total_lines,
      matched_lines: match_indices.size,
      has_more: (offset + chunk_size) < match_indices.size,
      loaded_lines: [ offset + lines.size, match_indices.size ].min
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

  def fetch_lines_by_indices(indices)
    return [] if indices.empty?

    indices_set = indices.to_set
    lines_by_index = {}
    current_idx = 0
    max_idx = indices_set.max

    File.foreach(filename) do |line|
      if indices_set.include?(current_idx)
        lines_by_index[current_idx] = StringSanitizer.tidy_bytes(line)
      end
      current_idx += 1
      break if current_idx > max_idx
    end

    indices.map { |idx| lines_by_index[idx] }
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
