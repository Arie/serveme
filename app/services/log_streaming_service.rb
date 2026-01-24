# typed: false
# frozen_string_literal: true

class LogStreamingService
  DEFAULT_CHUNK_SIZE = 1_000
  MAX_CHUNK_SIZE = 5_000

  # Cache for LogLineIndex instances, keyed by filename
  # Uses a simple LRU-style approach with max 20 cached indexes
  @@index_cache = {}
  @@index_cache_mutex = Mutex.new
  MAX_CACHED_INDEXES = 20

  attr_reader :filename, :search_query, :offset, :chunk_size

  def initialize(filename, search_query: nil, offset: 0, chunk_size: DEFAULT_CHUNK_SIZE)
    @filename = filename
    @search_query = search_query
    @offset = offset
    @chunk_size = [ chunk_size, MAX_CHUNK_SIZE ].min
  end

  # Get or create a cached LogLineIndex for the current file
  def self.get_index(filename)
    @@index_cache_mutex.synchronize do
      cache_key = filename.to_s

      # Check if we have a valid cached index
      if @@index_cache[cache_key]
        # Move to end (most recently used)
        index = @@index_cache.delete(cache_key)
        @@index_cache[cache_key] = index
        return index
      end

      # Create new index
      index = LogLineIndex.new(filename)

      # Evict oldest if cache is full
      if @@index_cache.size >= MAX_CACHED_INDEXES
        oldest_key = @@index_cache.keys.first
        @@index_cache.delete(oldest_key)
      end

      @@index_cache[cache_key] = index
      index
    end
  end

  # Stream a specific range of lines [start_line, end_line) using indexed seeking.
  # This is the key method for virtual scrolling - allows jumping to any position instantly.
  def stream_range(start_line, end_line)
    return empty_result unless File.exist?(filename)

    index = self.class.get_index(filename)
    total = index.total_lines

    # Clamp the range
    start_line = [ [ start_line, 0 ].max, total ].min
    end_line = [ [ end_line, start_line ].max, total ].min

    # Read the lines using the index
    raw_lines = index.read_range(start_line, end_line)
    lines = raw_lines.map { |line| StringSanitizer.tidy_bytes(line) }

    {
      lines: lines,
      total_lines: total,
      start_line: start_line,
      end_line: start_line + lines.size,
      has_more: index.has_more_after?(start_line + lines.size)
    }
  end

  # Get just the total line count (for initial page load)
  def total_line_count
    return 0 unless File.exist?(filename)
    index = self.class.get_index(filename)
    index.total_lines
  end

  # Return just the line indices that match the search query (for virtual scroll search)
  def search_line_indices
    return [] unless search_query.present?
    matches = search_with_ripgrep(search_query.downcase)
    matches.map { |m| m[:line_number] }
  end

  # Unified view method: returns lines for a viewport, with optional search
  # position_percent: 0-100, where in the file/matches to center the view
  # count: number of lines to return
  def view_at_position(position_percent:, count:)
    if search_query.present?
      view_search_results(position_percent: position_percent, count: count)
    else
      view_all_lines(position_percent: position_percent, count: count)
    end
  end

  private

  def view_all_lines(position_percent:, count:)
    total = total_line_count
    return empty_view_result if total == 0

    # Calculate center line from percentage
    center = (position_percent / 100.0 * total).round
    half = count / 2

    # Calculate range with bounds checking
    start_idx = [ center - half, 0 ].max
    end_idx = [ start_idx + count, total ].min
    start_idx = [ end_idx - count, 0 ].max  # Adjust if we hit the end

    # Get the lines using the index
    result = stream_range(start_idx, end_idx)

    {
      lines: result[:lines],
      total: total,
      total_matches: nil,
      start_index: start_idx,
      end_index: start_idx + result[:lines].size,
      is_search: false
    }
  end

  def view_search_results(position_percent:, count:)
    # Get all matching line indices via ripgrep
    match_indices = search_line_indices
    total_lines = total_line_count
    total_matches = match_indices.size

    return empty_view_result.merge(total: total_lines, total_matches: 0, is_search: true) if total_matches == 0

    # Calculate which matches to show based on percentage
    center = (position_percent / 100.0 * total_matches).round
    half = count / 2

    # Calculate range with bounds checking
    start_match = [ center - half, 0 ].max
    end_match = [ start_match + count, total_matches ].min
    start_match = [ end_match - count, 0 ].max  # Adjust if we hit the end

    # Get the actual line indices for these matches
    selected_match_indices = match_indices[start_match...end_match]

    # Read the actual lines from the file
    lines = read_specific_lines(selected_match_indices)

    {
      lines: lines,
      total: total_lines,
      total_matches: total_matches,
      start_index: start_match,
      end_index: start_match + lines.size,
      is_search: true,
      line_indices: selected_match_indices
    }
  end

  def read_specific_lines(line_indices)
    return [] if line_indices.empty?
    return [] unless File.exist?(filename)

    index = self.class.get_index(filename)
    lines = []

    File.open(filename, "r") do |f|
      line_indices.each do |line_num|
        byte_offset = index[line_num]
        next unless byte_offset

        f.seek(byte_offset)
        line = f.gets
        lines << StringSanitizer.tidy_bytes(line) if line
      end
    end

    lines
  end

  def empty_view_result
    {
      lines: [],
      total: 0,
      total_matches: nil,
      start_index: 0,
      end_index: 0,
      is_search: false
    }
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

  def empty_result
    {
      lines: [],
      total_lines: 0,
      start_line: 0,
      end_line: 0,
      has_more: false
    }
  end
end
