# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LogStreamingService do
  let(:tmpdir) { Dir.mktmpdir('log_streaming_service') }
  let(:log_lines) do
    [
      "L 01/01/2026 - 10:00:00: World triggered \"Round_Start\"\n",
      "L 01/01/2026 - 10:00:05: \"Alice<2><[U:1:1]><Red>\" say \"hello there\"\n",
      "L 01/01/2026 - 10:00:15: \"Bob<3><[U:1:2]><Blue>\" say \"HELLO back\"\n",
      "L 01/01/2026 - 10:00:16: \"Alice<2><[U:1:1]><Red>\" killed \"Bob<3><[U:1:2]><Blue>\"\n",
      "L 01/01/2026 - 10:00:30: \"Carol<4><[U:1:3]><Red>\" say \"hello again\"\n",
      "L 01/01/2026 - 10:00:31: World triggered \"Round_Win\"\n"
    ]
  end
  let(:log_path) { File.join(tmpdir, 'test.log') }
  let(:missing_path) { File.join(tmpdir, 'missing.log') }

  before { File.write(log_path, log_lines.join) }

  after { FileUtils.remove_entry(tmpdir) }

  let(:numbered_log) do
    lambda do |count|
      path = File.join(tmpdir, "numbered_#{count}.log")
      File.write(path, (0...count).map { |i| "line #{i}\n" }.join)
      path
    end
  end

  describe '#initialize' do
    it 'caps the chunk size at MAX_CHUNK_SIZE' do
      service = described_class.new(log_path, chunk_size: 50_000)
      expect(service.chunk_size).to eq(LogStreamingService::MAX_CHUNK_SIZE)
    end

    it 'keeps chunk sizes below the maximum' do
      service = described_class.new(log_path, chunk_size: 10, offset: 3, search_query: 'foo')
      expect(service.chunk_size).to eq(10)
      expect(service.offset).to eq(3)
      expect(service.search_query).to eq('foo')
    end
  end

  describe '.get_index' do
    around do |example|
      original = described_class.class_variable_get(:@@index_cache)
      described_class.class_variable_set(:@@index_cache, {})
      example.run
    ensure
      described_class.class_variable_set(:@@index_cache, original)
    end

    it 'returns the same cached index for the same filename, regardless of String or Pathname' do
      first = described_class.get_index(log_path)
      second = described_class.get_index(Pathname.new(log_path))
      expect(second).to be(first)
    end

    it 'moves a cache hit to the most recently used position' do
      a = File.join(tmpdir, 'a.log')
      b = File.join(tmpdir, 'b.log')
      described_class.get_index(a)
      described_class.get_index(b)
      described_class.get_index(a)
      expect(described_class.class_variable_get(:@@index_cache).keys).to eq([ b, a ])
    end

    it 'evicts the least recently used index when the cache is full' do
      paths = (0..LogStreamingService::MAX_CACHED_INDEXES).map { |i| File.join(tmpdir, "f#{i}.log") }
      first_index = described_class.get_index(paths.first)
      paths.drop(1).each { |p| described_class.get_index(p) }

      cache = described_class.class_variable_get(:@@index_cache)
      expect(cache.size).to eq(LogStreamingService::MAX_CACHED_INDEXES)
      expect(cache.keys).not_to include(paths.first)
      expect(cache.keys.last).to eq(paths.last)
      expect(described_class.get_index(paths.first)).not_to be(first_index)
    end
  end

  describe '#stream_range' do
    it 'returns an empty result for a missing file' do
      expect(described_class.new(missing_path).stream_range(0, 10)).to eq(
        lines: [], total_lines: 0, start_line: 0, end_line: 0, has_more: false
      )
    end

    it 'returns the requested range with metadata' do
      result = described_class.new(log_path).stream_range(1, 3)
      expect(result[:lines]).to eq(log_lines[1...3])
      expect(result[:total_lines]).to eq(6)
      expect(result[:start_line]).to eq(1)
      expect(result[:end_line]).to eq(3)
      expect(result[:has_more]).to be(true)
    end

    it 'clamps out-of-range bounds' do
      result = described_class.new(log_path).stream_range(-5, 100)
      expect(result[:lines]).to eq(log_lines)
      expect(result[:start_line]).to eq(0)
      expect(result[:end_line]).to eq(6)
      expect(result[:has_more]).to be(false)
    end

    it 'returns nothing when end is before start' do
      result = described_class.new(log_path).stream_range(4, 2)
      expect(result[:lines]).to eq([])
      expect(result[:start_line]).to eq(4)
      expect(result[:end_line]).to eq(4)
    end

    it 'repairs invalid UTF-8 bytes' do
      path = File.join(tmpdir, 'binary.log')
      File.binwrite(path, "caf\xE9\n".b)
      line = described_class.new(path).stream_range(0, 1)[:lines].first
      expect(line).to be_valid_encoding
      expect(line).to eq("café\n")
    end

    it 'picks up lines appended after the index was built' do
      service = described_class.new(log_path)
      expect(service.stream_range(0, 100)[:total_lines]).to eq(6)
      File.open(log_path, 'a') { |f| f.write("appended\n") }
      result = service.stream_range(6, 100)
      expect(result[:total_lines]).to eq(7)
      expect(result[:lines]).to eq([ "appended\n" ])
    end
  end

  describe '#total_line_count' do
    it 'counts lines in the file' do
      expect(described_class.new(log_path).total_line_count).to eq(6)
    end

    it 'is 0 for a missing file' do
      expect(described_class.new(missing_path).total_line_count).to eq(0)
    end
  end

  describe '#timestamp_index' do
    it 'returns 10-second bucket transitions' do
      expect(described_class.new(log_path).timestamp_index).to eq(
        [ [ 0, '10:00:00' ], [ 2, '10:00:15' ], [ 4, '10:00:30' ] ]
      )
    end

    it 'is empty for a missing file' do
      expect(described_class.new(missing_path).timestamp_index).to eq([])
    end
  end

  describe '#search_line_indices' do
    it 'returns zero-based line numbers of case-insensitive matches' do
      expect(described_class.new(log_path, search_query: 'HeLLo').search_line_indices).to eq([ 1, 2, 4 ])
    end

    it 'treats the query as a fixed string, not a regex' do
      expect(described_class.new(log_path, search_query: 'U:1:.').search_line_indices).to eq([])
      expect(described_class.new(log_path, search_query: '[U:1:3]').search_line_indices).to eq([ 4 ])
    end

    it 'returns an empty array without a query' do
      expect(described_class.new(log_path, search_query: nil).search_line_indices).to eq([])
      expect(described_class.new(log_path, search_query: '  ').search_line_indices).to eq([])
    end

    it 'returns an empty array when nothing matches' do
      expect(described_class.new(log_path, search_query: 'nonexistent').search_line_indices).to eq([])
    end

    # Never run rg with an option-like query here: without the fix, --pre=sh
    # runs every file under the current directory (the repo) through sh.
    it 'passes the query as an explicit pattern so it cannot inject ripgrep options' do
      argv = nil
      expect(IO).to receive(:popen) { |args| argv = args }
      described_class.new(log_path, search_query: '--pre=sh').search_line_indices
      expect(argv.last(4)).to eq([ '-e', '--pre=sh', '--', log_path ])
    end

    it 'matches queries that start with a dash as plain text' do
      path = File.join(tmpdir, 'dash.log')
      File.write(path, "one\ntwo --unknown-flag three\n")
      expect(described_class.new(path, search_query: '--unknown-flag').search_line_indices).to eq([ 1 ])
    end

    it 'truncates very long queries to 200 characters' do
      query = 'x' * 250
      expect(IO).to receive(:popen).with(array_including('x' * 200)).and_call_original
      expect(described_class.new(log_path, search_query: query).search_line_indices).to eq([])
    end
  end

  describe '#view_at_line' do
    it 'centers the view on the target line' do
      path = numbered_log.call(100)
      result = described_class.new(path).view_at_line(target_line: 50, count: 10)
      expect(result).to include(total: 100, total_matches: nil, start_index: 45, end_index: 55, is_search: false)
      expect(result[:lines].first).to eq("line 45\n")
      expect(result[:lines].size).to eq(10)
    end

    it 'shifts the window back when the target is near the end' do
      path = numbered_log.call(100)
      result = described_class.new(path).view_at_line(target_line: 99, count: 10)
      expect(result[:start_index]).to eq(90)
      expect(result[:end_index]).to eq(100)
      expect(result[:lines].last).to eq("line 99\n")
    end

    it 'starts at 0 when the target is near the start' do
      path = numbered_log.call(100)
      result = described_class.new(path).view_at_line(target_line: 2, count: 10)
      expect(result[:start_index]).to eq(0)
      expect(result[:lines].first).to eq("line 0\n")
    end

    it 'returns an empty view for a missing file' do
      expect(described_class.new(missing_path).view_at_line(target_line: 5, count: 10)).to eq(
        lines: [], total: 0, total_matches: nil, start_index: 0, end_index: 0, is_search: false
      )
    end
  end

  describe '#view_at_position' do
    context 'without a search query' do
      it 'centers the view on the given percentage of the file' do
        path = numbered_log.call(100)
        result = described_class.new(path).view_at_position(position_percent: 50, count: 10)
        expect(result).to include(total: 100, start_index: 45, end_index: 55, is_search: false, total_matches: nil)
        expect(result[:lines].first).to eq("line 45\n")
      end

      it 'shows the start of the file at 0%' do
        path = numbered_log.call(100)
        result = described_class.new(path).view_at_position(position_percent: 0, count: 10)
        expect(result[:start_index]).to eq(0)
        expect(result[:lines]).to eq((0...10).map { |i| "line #{i}\n" })
      end

      it 'shows the end of the file at 100%' do
        path = numbered_log.call(100)
        result = described_class.new(path).view_at_position(position_percent: 100, count: 10)
        expect(result[:start_index]).to eq(90)
        expect(result[:end_index]).to eq(100)
      end

      it 'returns all lines when count exceeds the file size' do
        result = described_class.new(log_path).view_at_position(position_percent: 50, count: 500)
        expect(result[:lines]).to eq(log_lines)
        expect(result[:start_index]).to eq(0)
        expect(result[:end_index]).to eq(6)
      end

      it 'returns an empty view for an empty file' do
        path = File.join(tmpdir, 'empty.log')
        File.write(path, '')
        result = described_class.new(path).view_at_position(position_percent: 50, count: 10)
        expect(result).to include(lines: [], total: 0, is_search: false)
      end
    end

    context 'with a search query' do
      it 'returns the matching lines and their line indices' do
        result = described_class.new(log_path, search_query: 'hello').view_at_position(position_percent: 0, count: 10)
        expect(result[:lines]).to eq([ log_lines[1], log_lines[2], log_lines[4] ])
        expect(result).to include(
          total: 6, total_matches: 3, start_index: 0, end_index: 3, is_search: true, line_indices: [ 1, 2, 4 ]
        )
      end

      it 'pages through matches by percentage' do
        path = numbered_log.call(100)
        # "line 1" matches line 1 and lines 10-19: 11 matches
        result = described_class.new(path, search_query: 'line 1').view_at_position(position_percent: 100, count: 4)
        expect(result[:total_matches]).to eq(11)
        expect(result[:start_index]).to eq(7)
        expect(result[:end_index]).to eq(11)
        expect(result[:line_indices]).to eq([ 16, 17, 18, 19 ])
        expect(result[:lines]).to eq([ "line 16\n", "line 17\n", "line 18\n", "line 19\n" ])
      end

      it 'returns an empty search view when nothing matches' do
        result = described_class.new(log_path, search_query: 'nothing here').view_at_position(position_percent: 0, count: 10)
        expect(result).to eq(
          lines: [], total: 6, total_matches: 0, start_index: 0, end_index: 0, is_search: true
        )
      end

      it 'skips match indices that fall outside the file' do
        service = described_class.new(log_path, search_query: 'hello')
        allow(service).to receive(:search_line_indices).and_return([ 1, 999 ])
        result = service.view_at_position(position_percent: 0, count: 10)
        expect(result[:lines]).to eq([ log_lines[1] ])
        expect(result[:total_matches]).to eq(2)
      end

      it 'returns no lines when the file is missing' do
        service = described_class.new(missing_path, search_query: 'hello')
        allow(service).to receive(:search_line_indices).and_return([ 0 ])
        expect(service.view_at_position(position_percent: 0, count: 10)[:lines]).to eq([])
      end
    end
  end

  # stream_forward / stream_reverse are private and currently have no callers
  describe 'chunked streaming' do
    let(:path) { numbered_log.call(10) }

    let(:stream) { ->(direction, **opts) { described_class.new(path, **opts).send(direction) } }

    describe '#stream_forward' do
      it 'returns a chunk of lines oldest first' do
        result = stream.call(:stream_forward, offset: 2, chunk_size: 3)
        expect(result).to eq(
          lines: [ "line 2\n", "line 3\n", "line 4\n" ],
          total_lines: 10, matched_lines: 10, has_more: true, loaded_lines: 5, next_offset: 5
        )
      end

      it 'reports no more lines on the last chunk' do
        result = stream.call(:stream_forward, offset: 8, chunk_size: 5)
        expect(result[:lines]).to eq([ "line 8\n", "line 9\n" ])
        expect(result[:has_more]).to be(false)
        expect(result[:loaded_lines]).to eq(10)
      end

      it 'pages through search matches' do
        result = stream.call(:stream_forward, search_query: 'LINE', offset: 1, chunk_size: 2)
        expect(result[:lines]).to eq([ "line 1\n", "line 2\n" ])
        expect(result).to include(total_lines: 10, matched_lines: 10, has_more: true, loaded_lines: 3, next_offset: 3)
      end

      it 'returns an empty page when the offset is beyond the matches' do
        result = stream.call(:stream_forward, search_query: 'line 5', offset: 5, chunk_size: 2)
        expect(result[:lines]).to eq([])
        expect(result[:matched_lines]).to eq(1)
        expect(result[:has_more]).to be(false)
      end
    end

    describe '#stream_reverse' do
      it 'returns a chunk of lines newest first' do
        result = stream.call(:stream_reverse, offset: 0, chunk_size: 3)
        expect(result).to eq(
          lines: [ "line 9\n", "line 8\n", "line 7\n" ],
          total_lines: 10, matched_lines: 10, has_more: true, loaded_lines: 3, next_offset: 3
        )
      end

      it 'returns the oldest lines on the last chunk' do
        result = stream.call(:stream_reverse, offset: 8, chunk_size: 5)
        expect(result[:lines]).to eq([ "line 1\n", "line 0\n" ])
        expect(result[:has_more]).to be(false)
      end

      it 'pages through search matches newest first' do
        result = stream.call(:stream_reverse, search_query: 'line', offset: 0, chunk_size: 2)
        expect(result[:lines]).to eq([ "line 9\n", "line 8\n" ])
        expect(result).to include(matched_lines: 10, has_more: true, loaded_lines: 2)
      end

      it 'returns an empty page when the offset is beyond the matches' do
        result = stream.call(:stream_reverse, search_query: 'line 5', offset: 3, chunk_size: 2)
        expect(result[:lines]).to eq([])
        expect(result[:has_more]).to be(false)
      end
    end

    it 'counts zero lines for a missing file' do
      expect(described_class.new(missing_path).send(:count_lines_fast)).to eq(0)
    end

    it 'returns nil when sanitizing a nil search term' do
      expect(described_class.new(path).send(:sanitize_search_term, nil)).to be_nil
    end

    it 'strips invalid bytes from the search term' do
      term = "li\xFFne 3".dup.force_encoding('UTF-8')
      expect(described_class.new(path).send(:sanitize_search_term, term)).to eq('line 3')
    end
  end
end
