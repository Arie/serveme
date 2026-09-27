# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LeagueAdminAiService do
  let(:user) { create :user, uid: '76561197960497430' }
  let(:messages_resource) { double('messages') }
  let(:client) { double('Anthropic::Client', messages: messages_resource) }
  let(:service) { described_class.new(user: user) }
  let(:events) { [] }
  let(:collector) { ->(type, data) { events << [ type, data ] } }
  let(:stream_calls) { [] }

  before do
    allow(Anthropic::Client).to receive(:new).and_return(client)
  end

  define_method(:text_response) do |text, stop_reason: :end_turn|
    [
      Anthropic::RawContentBlockStartEvent.new(index: 0, type: :content_block_start, content_block: { type: :text, text: '', citations: nil }),
      Anthropic::RawContentBlockDeltaEvent.new(index: 0, type: :content_block_delta, delta: { type: :text_delta, text: text }),
      Anthropic::RawContentBlockStopEvent.new(index: 0, type: :content_block_stop),
      Anthropic::RawMessageDeltaEvent.new(type: :message_delta, delta: { stop_reason: stop_reason, stop_sequence: nil }, usage: { output_tokens: 1 })
    ]
  end

  define_method(:tool_use_response) do |tools, preamble: nil|
    evs = []
    evs.concat(text_response(preamble)[0..2]) if preamble
    tools.each_with_index do |(id, name, json), i|
      evs << Anthropic::RawContentBlockStartEvent.new(index: i + 1, type: :content_block_start, content_block: { type: :tool_use, id: id, name: name, input: {} })
      # Split the JSON across two deltas to exercise accumulation
      half = json.length / 2
      evs << Anthropic::RawContentBlockDeltaEvent.new(index: i + 1, type: :content_block_delta, delta: { type: :input_json_delta, partial_json: json[0, half] })
      evs << Anthropic::RawContentBlockDeltaEvent.new(index: i + 1, type: :content_block_delta, delta: { type: :input_json_delta, partial_json: json[half..] })
      evs << Anthropic::RawContentBlockStopEvent.new(index: i + 1, type: :content_block_stop)
    end
    evs << Anthropic::RawMessageDeltaEvent.new(type: :message_delta, delta: { stop_reason: :tool_use, stop_sequence: nil }, usage: { output_tokens: 1 })
    evs
  end

  define_method(:stub_stream) do |*responses|
    queue = responses.dup
    allow(messages_resource).to receive(:stream_raw) do |**kwargs|
      stream_calls << Marshal.load(Marshal.dump(kwargs.except(:request_options))).merge(request_options: kwargs[:request_options])
      queue.shift || text_response('fallback')
    end
  end

  define_method(:tool_results_in) do |call|
    call[:messages].last[:content].select { |c| c[:type] == 'tool_result' }
  end

  describe '#initialize' do
    it 'builds an Anthropic client with the configured api key' do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:anthropic, :api_key).and_return('sk-test')

      described_class.new(user: user)

      expect(Anthropic::Client).to have_received(:new).with(api_key: 'sk-test')
    end
  end

  describe '#stream_response' do
    context 'with a plain text answer' do
      it 'streams tokens and makes a single API call' do
        stub_stream(text_response('Hello admin'))

        service.stream_response(messages: [ { role: 'user', content: 'hi' } ], &collector)

        expect(events).to eq([ [ :token, 'Hello admin' ] ])
        expect(stream_calls.size).to eq(1)
      end

      it 'sends the model, system prompt with cache control, timeout and tool definitions' do
        stub_stream(text_response('ok'))

        service.stream_response(messages: [ { role: 'user', content: 'hi' } ], &collector)

        call = stream_calls.first
        expect(call[:model]).to eq('claude-haiku-4-5')
        expect(call[:max_tokens]).to eq(8192)
        expect(call[:system]).to eq([ { type: 'text', text: described_class::SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } } ])
        expect(call[:request_options]).to eq(timeout: described_class::API_TIMEOUT)

        tool_names = call[:tools].map { |t| t[:name] }
        expect(tool_names).to eq(described_class::ALLOWED_TOOLS)
        expect(call[:tools].last[:cache_control]).to eq(type: 'ephemeral')
        expect(call[:tools][0..-2]).to all(satisfy { |t| !t.key?(:cache_control) })
        expect(call[:tools].first[:input_schema]).to eq(Mcp::Tools::SearchAltsTool.input_schema)
        expect(call[:tools].first[:description]).to eq(Mcp::Tools::SearchAltsTool.description)
      end

      it 'skips allowed tools that are missing from the registry' do
        allow(Mcp::ToolRegistry).to receive(:find).and_call_original
        allow(Mcp::ToolRegistry).to receive(:find).with('search_by_asn').and_return(nil)
        stub_stream(text_response('ok'))

        service.stream_response(messages: [ { role: 'user', content: 'hi' } ], &collector)

        expect(stream_calls.first[:tools].map { |t| t[:name] }).not_to include('search_by_asn')
        expect(stream_calls.first[:tools].size).to eq(described_class::ALLOWED_TOOLS.size - 1)
      end

      it 'sends no tools with cache control when the registry has none' do
        allow(Mcp::ToolRegistry).to receive(:find).and_return(nil)
        stub_stream(text_response('ok'))

        service.stream_response(messages: [ { role: 'user', content: 'hi' } ], &collector)

        expect(stream_calls.first[:tools]).to eq([])
      end
    end

    describe 'cache breakpoints' do
      it 'wraps a trailing string message in a text block with cache control' do
        stub_stream(text_response('ok'))

        service.stream_response(messages: [ { role: 'user', content: 'hi' } ], &collector)

        expect(stream_calls.first[:messages]).to eq([
          { role: 'user', content: [ { type: 'text', text: 'hi', cache_control: { type: 'ephemeral' } } ] }
        ])
      end

      it 'adds cache control only to the last block of an array message without mutating the input' do
        stub_stream(text_response('ok'))
        content = [ { type: 'text', text: 'a' }, { type: 'text', text: 'b' } ]
        messages = [ { role: 'assistant', content: 'earlier' }, { role: 'user', content: content } ]

        service.stream_response(messages: messages, &collector)

        sent = stream_calls.first[:messages]
        expect(sent.first).to eq(role: 'assistant', content: 'earlier')
        expect(sent.last[:content]).to eq([
          { type: 'text', text: 'a' },
          { type: 'text', text: 'b', cache_control: { type: 'ephemeral' } }
        ])
        expect(content.last).not_to have_key(:cache_control)
      end

      it 'leaves an empty-array last message alone' do
        stub_stream(text_response('ok'))

        service.stream_response(messages: [ { role: 'user', content: [] } ], &collector)

        expect(stream_calls.first[:messages]).to eq([ { role: 'user', content: [] } ])
      end

      it 'passes an empty message list through unchanged' do
        stub_stream(text_response('ok'))

        service.stream_response(messages: [], &collector)

        expect(stream_calls.first[:messages]).to eq([])
      end
    end

    describe 'Steam ID normalization' do
      define_method(:sent_text) do
        stream_calls.first[:messages].first[:content].first[:text]
      end

      before { stub_stream(text_response('ok')) }

      it 'expands legacy STEAM_ IDs to ID64 and ID3' do
        service.stream_response(messages: [ { role: 'user', content: 'check STEAM_0:0:115851 please' } ], &collector)

        expect(sent_text).to eq('check 76561197960497430 ([U:1:231702]) please')
      end

      it 'expands a mix of legacy and ID3 IDs in one message' do
        service.stream_response(messages: [ { role: 'user', content: 'STEAM_0:0:115851 and [U:1:231702]' } ], &collector)

        expect(sent_text).to eq('76561197960497430 ([U:1:231702]) and 76561197960497430 ([U:1:231702])')
      end

      it 'expands ID3 IDs to ID64 and ID3' do
        service.stream_response(messages: [ { role: 'user', content: 'check [U:1:231702]' } ], &collector)

        expect(sent_text).to eq('check 76561197960497430 ([U:1:231702])')
      end

      it 'annotates bare ID64s with their ID3' do
        service.stream_response(messages: [ { role: 'user', content: 'check 76561197960497430' } ], &collector)

        expect(sent_text).to eq('check 76561197960497430 ([U:1:231702])')
      end

      it 'does not double-annotate ID64s produced by an earlier conversion' do
        service.stream_response(messages: [ { role: 'user', content: '[U:1:231702] and 76561197960497430' } ], &collector)

        expect(sent_text).to eq('76561197960497430 ([U:1:231702]) and 76561197960497430')
      end

      it 'leaves the ID untouched when conversion fails' do
        allow(SteamCondenser::Community::SteamId).to receive(:steam_id_to_community_id).and_raise(StandardError, 'bad')

        service.stream_response(messages: [ { role: 'user', content: 'check STEAM_0:0:115851' } ], &collector)

        expect(sent_text).to eq('check STEAM_0:0:115851')
      end

      it 'leaves a bare ID64 untouched when ID3 conversion fails' do
        allow(SteamCondenser::Community::SteamId).to receive(:community_id_to_steam_id3).and_raise(StandardError, 'bad')

        service.stream_response(messages: [ { role: 'user', content: 'check 76561197960497430' } ], &collector)

        expect(sent_text).to eq('check 76561197960497430')
      end

      it 'does not touch assistant messages or non-string user content' do
        messages = [
          { role: 'assistant', content: 'STEAM_0:0:115851' },
          { role: 'user', content: [ { type: 'text', text: 'STEAM_0:0:115851' } ] }
        ]

        service.stream_response(messages: messages, &collector)

        sent = stream_calls.first[:messages]
        expect(sent.first[:content]).to eq('STEAM_0:0:115851')
        expect(sent.last[:content].first[:text]).to eq('STEAM_0:0:115851')
      end
    end

    describe 'tool use loop' do
      let(:get_user_tool) { instance_double(Mcp::Tools::GetUserTool) }

      before do
        allow(Mcp::Tools::GetUserTool).to receive(:new).with(user).and_return(get_user_tool)
        allow(get_user_tool).to receive(:execute).and_return({ user: { uid: '76561197960497430', nickname: 'Arie' } })
      end

      it 'executes the requested tool, sends back the result and streams the final answer' do
        stub_stream(
          tool_use_response([ [ 'tu_1', 'get_user', '{"query":"76561197960497430"}' ] ], preamble: 'Looking...'),
          text_response('Done')
        )

        service.stream_response(messages: [ { role: 'user', content: 'who is this' } ], &collector)

        expect(get_user_tool).to have_received(:execute).with({ query: '76561197960497430' })
        expect(events).to eq([
          [ :token, 'Looking...' ],
          [ :tool_call, { id: 'tu_1', label: 'Looking up user: 76561197960497430' } ],
          [ :token, 'Done' ]
        ])

        second = stream_calls[1][:messages]
        expect(second.size).to eq(3)
        assistant = second[1]
        expect(assistant[:role]).to eq('assistant')
        expect(assistant[:content]).to eq([
          { type: 'text', text: 'Looking...' },
          { type: 'tool_use', id: 'tu_1', name: 'get_user', input: { 'query' => '76561197960497430' } }
        ])
        results = tool_results_in(stream_calls[1])
        expect(results.size).to eq(1)
        expect(results.first[:tool_use_id]).to eq('tu_1')
        expect(results.first[:cache_control]).to eq(type: 'ephemeral')
        expect(JSON.parse(results.first[:content])).to eq('user' => { 'uid' => '76561197960497430', 'nickname' => 'Arie' })
      end

      it 'executes multiple tool calls from one round in order' do
        stub_stream(
          tool_use_response([
                              [ 'tu_1', 'get_user', '{"query":"a"}' ],
                              [ 'tu_2', 'get_user', '{"query":"b"}' ]
                            ]),
          text_response('Done')
        )

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(get_user_tool).to have_received(:execute).with({ query: 'a' }).ordered
        expect(get_user_tool).to have_received(:execute).with({ query: 'b' }).ordered
        expect(tool_results_in(stream_calls[1]).map { |r| r[:tool_use_id] }).to eq(%w[tu_1 tu_2])
      end

      it 'parses invalid tool input JSON as an empty hash' do
        stub_stream(tool_use_response([ [ 'tu_1', 'get_user', '{not json' ] ]), text_response('Done'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(get_user_tool).to have_received(:execute).with({})
        expect(events).to include([ :tool_call, { id: 'tu_1', label: 'Looking up user' } ])
      end

      it 'stops when stop_reason is tool_use but no tool blocks were produced' do
        stub_stream(text_response('odd', stop_reason: :tool_use))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(stream_calls.size).to eq(1)
        expect(get_user_tool).not_to have_received(:execute)
      end

      it 'returns an error result for unknown tools' do
        stub_stream(tool_use_response([ [ 'tu_1', 'drop_database', '{}' ] ]), text_response('Done'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(events).to include([ :tool_call, { id: 'tu_1', label: 'drop_database' } ])
        expect(JSON.parse(tool_results_in(stream_calls[1]).first[:content])).to eq('error' => 'Unknown tool: drop_database')
      end

      it 'turns tool exceptions into error results and logs them' do
        allow(get_user_tool).to receive(:execute).and_raise(StandardError, 'boom')
        allow(Rails.logger).to receive(:error)
        stub_stream(tool_use_response([ [ 'tu_1', 'get_user', '{"query":"x"}' ] ]), text_response('Done'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(Rails.logger).to have_received(:error).with('[LeagueAdminAI] Tool get_user error: boom')
        expect(JSON.parse(tool_results_in(stream_calls[1]).first[:content])).to eq('error' => 'boom')
        expect(events.last).to eq([ :token, 'Done' ])
      end

      it 'truncates oversized tool results' do
        big = 'x' * (described_class::MAX_TOOL_RESULT_CHARS + 100)
        allow(get_user_tool).to receive(:execute).and_return({ data: big })
        stub_stream(tool_use_response([ [ 'tu_1', 'get_user', '{"query":"x"}' ] ]), text_response('Done'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        content = tool_results_in(stream_calls[1]).first[:content]
        full_length = { data: big }.to_json.length
        expect(content).to start_with({ data: big }.to_json[0, described_class::MAX_TOOL_RESULT_CHARS])
        expect(content).to end_with("[TRUNCATED — result was #{full_length} characters, showing first #{described_class::MAX_TOOL_RESULT_CHARS}]")
      end

      it 'sends keepalives while a tool is still running' do
        thread = double('thread')
        allow(thread).to receive(:join).with(5).and_return(nil, nil, thread)
        allow(Thread).to receive(:new) do |&blk|
          blk.call
          thread
        end
        stub_stream(tool_use_response([ [ 'tu_1', 'get_user', '{"query":"x"}' ] ]), text_response('Done'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(events.count { |e| e == [ :keepalive, nil ] }).to eq(2)
        expect(JSON.parse(tool_results_in(stream_calls[1]).first[:content])).to include('user')
      end

      it 'forces a tool-less summary after MAX_TOOL_ROUNDS' do
        responses = Array.new(described_class::MAX_TOOL_ROUNDS) do |i|
          tool_use_response([ [ "tu_#{i}", 'get_user', '{"query":"x"}' ] ])
        end
        stub_stream(*responses, text_response('Summary'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(stream_calls.size).to eq(described_class::MAX_TOOL_ROUNDS + 1)
        expect(get_user_tool).to have_received(:execute).exactly(described_class::MAX_TOOL_ROUNDS - 1).times

        final = stream_calls.last
        expect(final[:tools]).to eq([])
        expect(final[:messages][-2][:role]).to eq('assistant')
        expect(final[:messages][-2][:content].first[:id]).to eq("tu_#{described_class::MAX_TOOL_ROUNDS - 1}")
        expect(final[:messages].last[:content].first[:text]).to eq('You have reached the tool call limit. Summarize your findings now with the data you have.')
        expect(events.last).to eq([ :token, 'Summary' ])
      end
    end

    describe 'tool labels' do
      before do
        allow(Mcp::Tools::SearchReservationLogsTool).to receive(:new).and_return(instance_double(Mcp::Tools::SearchReservationLogsTool, execute: {}))
        allow(Mcp::Tools::SearchByAsnTool).to receive(:new).and_return(instance_double(Mcp::Tools::SearchByAsnTool, execute: {}))
      end

      it 'combines all present input details' do
        stub_stream(
          tool_use_response([
                              [ 'tu_1', 'search_reservation_logs', { steam_uid: '765', reservation_id: 42, search_term: 'say ', ip: '' }.to_json ],
                              [ 'tu_2', 'search_by_asn', { asn_number: 1136, ip: '1.2.3.4', query: 'kpn' }.to_json ]
                            ]),
          text_response('Done')
        )

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        labels = events.select { |t, _| t == :tool_call }.map { |_, d| d[:label] }
        expect(labels).to eq([
          'Searching reservation logs: 765, reservation #42, "say "',
          'Searching by ASN: kpn, IP 1.2.3.4, 1136'
        ])
      end

      it 'uses the plain label when input is not a hash' do
        stub_stream(tool_use_response([ [ 'tu_1', 'search_by_asn', '[1,2]' ] ]), text_response('Done'))

        service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

        expect(events).to include([ :tool_call, { id: 'tu_1', label: 'Searching by ASN' } ])
      end
    end

    describe 'search_alts summarization' do
      let(:target_uid) { '76561197960497430' }
      let(:alts_tool) { instance_double(Mcp::Tools::SearchAltsTool) }
      let(:raw_result) do
        {
          target: target_uid,
          accounts: [
            {
              steam_uid: '76561198000000001', name: 'Alt', ip: '9.9.9.9',
              reservation_count: 1, first_seen: '2026-01-01', last_seen: '2026-01-02'
            },
            {
              steam_uid: '76561198000000002', all_names: %w[a b c d e f a], all_ips: [ '10.0.0.1', '10.0.0.2', '10.0.0.1' ],
              reservation_count: 7, asn_number: 174, asn_organization: 'Cogent',
              first_seen: '2025-01-01', last_seen: '2026-02-01'
            },
            {
              steam_uid: target_uid, all_names: [ 'Arie' ], all_ips: [ '1.1.1.1', '2.2.2.2', '3.3.3.3' ],
              reservation_count: 3, asn_number: 1136, asn_organization: 'KPN'
            },
            {
              steam_uid: '76561198000000003', name: 'Mid', ip: '4.4.4.4', reservation_count: '2'
            }
          ],
          asn_info: { number: 1136 },
          stac_detections: [ { detection: 'aimbot' } ]
        }
      end

      define_method(:summary) do
        JSON.parse(tool_results_in(stream_calls[1]).first[:content])
      end

      before do
        allow(Mcp::Tools::SearchAltsTool).to receive(:new).with(user).and_return(alts_tool)
        allow(alts_tool).to receive(:execute).and_return(raw_result)
        allow(ReservationPlayer).to receive_messages(banned_asns: [ 174 ], vpn_ranges: [ IPAddr.new('3.3.3.0/24') ])
        allow(ReservationPlayer).to receive(:banned_ip?).and_return(nil)
        allow(ReservationPlayer).to receive(:banned_ip?).with('2.2.2.2').and_return('residential proxy')
        allow(ReservationPlayer).to receive(:banned_uid?).and_return(nil)
        allow(ReservationPlayer).to receive(:banned_uid?).with(76_561_198_000_000_002).and_return('cheating')

        IpLookup.create!(ip: '1.1.1.1', is_proxy: true, is_residential_proxy: false, fraud_score: 90,
                         isp: 'BadISP', country_code: 'NL', false_positive: true, is_banned: false)
        IpLookup.create!(ip: '10.0.0.1', is_proxy: false, is_residential_proxy: true, fraud_score: 100,
                         isp: 'Resi', country_code: 'US', is_banned: true, ban_reason: 'resi proxy')
        IpLookup.create!(ip: '4.4.4.4', is_proxy: false, is_residential_proxy: false, fraud_score: 10)

        stub_stream(
          tool_use_response([ [ 'tu_1', 'search_alts', { steam_uid: target_uid, cross_reference: true }.to_json ] ]),
          text_response('Done')
        )
        service.stream_response(messages: [ { role: 'user', content: 'check' } ], &collector)
      end

      it 'passes symbolized input to the tool and labels the call' do
        expect(alts_tool).to have_received(:execute).with({ steam_uid: target_uid, cross_reference: true })
        expect(events).to include([ :tool_call, { id: 'tu_1', label: "Searching for alt accounts: #{target_uid}" } ])
      end

      it 'returns summary counts and passes through asn and stac info' do
        expect(summary).to include(
          'target' => target_uid,
          'unique_accounts' => 4,
          'significant_accounts' => 3,
          'accounts_omitted_single_reservation' => 1,
          'asn_info' => { 'number' => 1136 },
          'stac_detections' => [ { 'detection' => 'aimbot' } ]
        )
      end

      it 'puts the target first, then sorts by reservation count, dropping single-reservation accounts' do
        expect(summary['accounts'].map { |a| a['steam_uid'] }).to eq([ target_uid, '76561198000000002', '76561198000000003' ])
        expect(summary['accounts'].map { |a| a['is_target'] }).to eq([ true, false, false ])
      end

      it 'summarizes the target account with proxy, banned IP and VPN data' do
        target = summary['accounts'].first
        expect(target).to include(
          'names' => [ 'Arie' ],
          'shared_ips' => [ '1.1.1.1', '2.2.2.2', '3.3.3.3' ],
          'ip_count' => 3,
          'reservation_count' => 3,
          'banned_ips' => [ { 'ip' => '2.2.2.2', 'reason' => 'residential proxy' } ],
          'vpn_ips' => [ '3.3.3.3' ],
          'asns' => [ { 'number' => 1136, 'org' => 'KPN' } ]
        )
        expect(target['proxy_ips']).to eq([
          {
            'ip' => '1.1.1.1', 'is_proxy' => true, 'is_residential_proxy' => false, 'fraud_score' => 90,
            'isp' => 'BadISP', 'country_code' => 'NL', 'false_positive' => true, 'is_banned' => false, 'ban_reason' => nil
          }
        ])
        expect(target).not_to have_key('banned_uid')
      end

      it 'dedupes IPs, caps names at five, flags banned ASNs and banned UIDs' do
        alt = summary['accounts'][1]
        expect(alt['names']).to eq(%w[a b c d e])
        expect(alt['shared_ips']).to eq([ '10.0.0.1', '10.0.0.2' ])
        expect(alt['ip_count']).to eq(2)
        expect(alt['asns']).to eq([ { 'number' => 174, 'org' => 'Cogent', 'banned' => true } ])
        expect(alt['banned_uid']).to eq('cheating')
        expect(alt['proxy_ips'].map { |p| p['ip'] }).to eq([ '10.0.0.1' ])
        expect(alt['proxy_ips'].first).to include('is_residential_proxy' => true, 'is_banned' => true, 'ban_reason' => 'resi proxy')
        expect(alt['first_seen']).to eq('2025-01-01')
        expect(alt['last_seen']).to eq('2026-02-01')
      end

      it 'falls back to single ip/name fields and ignores clean IP lookups' do
        mid = summary['accounts'].last
        expect(mid).to include(
          'names' => [ 'Mid' ],
          'shared_ips' => [ '4.4.4.4' ],
          'reservation_count' => 2,
          'proxy_ips' => [],
          'banned_ips' => [],
          'vpn_ips' => []
        )
        expect(mid['asns']).to eq([ { 'number' => nil, 'org' => nil } ])
      end
    end

    it 'does not summarize search_alts results without accounts' do
      alts_tool = instance_double(Mcp::Tools::SearchAltsTool, execute: { error: 'not found' })
      allow(Mcp::Tools::SearchAltsTool).to receive(:new).and_return(alts_tool)
      stub_stream(tool_use_response([ [ 'tu_1', 'search_alts', '{"steam_uid":"1"}' ] ]), text_response('Done'))

      service.stream_response(messages: [ { role: 'user', content: 'go' } ], &collector)

      expect(JSON.parse(tool_results_in(stream_calls[1]).first[:content])).to eq('error' => 'not found')
    end
  end
end
