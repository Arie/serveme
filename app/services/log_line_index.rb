# typed: false
# frozen_string_literal: true

# Provides efficient random access to log files by maintaining a byte-offset index.
# The index is built incrementally and extends automatically as the file grows.
#
# Performance characteristics:
# - Index building: O(n) for n lines, but only indexes what's needed
# - Random access: O(1) seek + O(chunk_size) read
# - File growth: Only indexes new portions, existing offsets remain valid
class LogLineIndex
  attr_reader :filename, :offsets, :indexed_to_byte

  def initialize(filename)
    @filename = filename
    @offsets = [ 0 ] # First line always starts at byte 0
    @indexed_to_byte = 0
    @mutex = Mutex.new
  end

  # Extend the index if the file has grown or if we need to reach a target line.
  # Thread-safe and idempotent.
  def extend_if_needed(target_line = nil)
    @mutex.synchronize do
      return unless File.exist?(filename)

      current_size = File.size(filename)
      return if current_size == @indexed_to_byte
      return if target_line && target_line < @offsets.size

      File.open(filename, "rb") do |f|
        f.seek(@indexed_to_byte)

        while (line = f.gets)
          @offsets << f.pos
          break if target_line && @offsets.size > target_line
        end

        @indexed_to_byte = f.pos
      end
    end
  end

  # Get the byte offset for a specific line number (0-indexed).
  def [](line_number)
    extend_if_needed(line_number)
    @offsets[line_number]
  end

  # Get the total number of indexed lines.
  # Extends the index to the end of the file if needed.
  def total_lines
    extend_if_needed
    # offsets array has n+1 entries for n lines (includes position after last line)
    [ @offsets.size - 1, 0 ].max
  end

  # Read a range of lines [start_line, end_line) efficiently using the index.
  # Returns an array of raw line strings.
  def read_range(start_line, end_line)
    extend_if_needed(end_line)

    return [] if start_line >= @offsets.size
    return [] unless File.exist?(filename)

    effective_end = [ end_line, @offsets.size - 1 ].min
    return [] if start_line >= effective_end

    lines = []
    File.open(filename, "r") do |f|
      f.seek(@offsets[start_line])
      (start_line...effective_end).each do
        line = f.gets
        break unless line
        lines << line
      end
    end
    lines
  end

  # Check if there are more lines beyond end_line
  def has_more_after?(end_line)
    extend_if_needed(end_line + 1)
    end_line < total_lines
  end

  # Get the current indexed percentage (for progress indication)
  def indexed_percentage
    return 0 unless File.exist?(filename)

    file_size = File.size(filename)
    return 100 if file_size == 0

    (@indexed_to_byte.to_f / file_size * 100).round(1)
  end
end
