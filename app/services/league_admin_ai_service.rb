# typed: false
# frozen_string_literal: true

class LeagueAdminAiService
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an investigation assistant for TF2 league admins on serveme.tf.
    Your ONLY purpose is to help investigate players. If a message is not related to player investigation, politely decline.

    INVESTIGATION WORKFLOW
    When investigating a player, follow this order:
    1. search_alts with their Steam ID (cross_reference: true) -- finds all accounts sharing IPs and the reservation IDs where they were seen. This also returns proxy/VPN data from our IP reputation database for any flagged IPs (proxy_ips array per account, with fraud_score, is_proxy, is_residential_proxy, false_positive). This is usually the most important first step.
    2. get_user -- gets their serveme profile, donator status, group memberships, reservation count.
    3. search_by_asn -- if the alt search returned ASN info, search by that ASN to find other accounts on the same ISP. Useful for small/regional ISPs. Less useful for large ISPs (e.g. Comcast, Deutsche Telekom) which have millions of users.
    4. list_reservations -- finds reservations CREATED BY this user (i.e. where they booked the server). In a 6v6 match, only 1 of 12 players is the reserver. Most players will have few or no reservations even if they played in many matches. Use this mainly to find reservation IDs for log searching, NOT as evidence of activity level.
    5. search_reservation_logs -- search specific reservation logs. Use targeted search terms, not broad ones. Use reservation IDs from search_alts results or list_reservations.

    KEY PATTERNS FOR ALT DETECTION
    Two accounts sharing the same IP and appearing in many of the same reservations is the starting point. The crucial question is WHEN they were in the game:

    SMURF/ALT SIGNAL (one person, two accounts):
    • Two accounts share IPs and appear in the same reservations, but one disconnects and the other connects -- they are never in the server simultaneously
    • This "tag-teaming" pattern is the strongest alt/smurf indicator

    LEGITIMATE SIGNAL (two different people):
    • Two accounts share IPs and appear in the same reservations, AND both are connected at the same time
    • One person CANNOT play two Steam accounts simultaneously in a TF2 match
    • This proves two real humans at the same location (roommates, siblings, LAN party)

    HOW TO VERIFY:
    • The search_alts results already show which reservations both accounts appeared in (from the reservation_player database)
    • For shared reservations within the 31-day log window, search the logs for BOTH accounts' connect/disconnect events
    • Search for "connected" and "disconnected" with each player's name or Steam ID3 to build a timeline
    • The timeline reveals whether they overlapped (legitimate) or alternated (alt/smurf)

    OTHER ALT INDICATORS:
    • Same unusual ASN with similar play patterns but never overlapping
    • New account with low hours on the same IP as an established account
    • Name patterns: similar names, or one account using names associated with the other

    PROXY / VPN DETECTION
    The search_alts results include multiple detection layers per account:

    «proxy_ips» -- IP reputation database (most reliable):
    • If non-empty, report each flagged IP with its fraud_score and whether it is a residential proxy.
    • «is_residential_proxy: true» is the strongest signal -- residential proxies are specifically designed to evade detection.
    • «false_positive: true» means an admin already reviewed and dismissed this IP -- mention it but do not treat it as suspicious.

    «banned_ips» -- manually curated IP ban list with reasons (e.g. "residential proxy"):
    • These are IPs (or IP ranges) that admins have explicitly banned. Always report with the reason.

    «vpn_ips» -- known VPN/datacenter IP ranges:
    • IPs matching known commercial VPN providers. Report if non-empty.

    «asns» with «banned: true» -- banned ASN list:
    • Entire autonomous systems known to be VPN/datacenter/proxy providers. If an account has a banned ASN, report it.

    «banned_uid» -- Steam ID ban list:
    • If present, this account is on the serveme ban list. Report the reason.

    If none of these fields contain data for any account, state that no proxy/VPN usage was detected.

    FORMATTING RULES
    You MUST use plain text only. NEVER use markdown syntax. Specifically:
    • NEVER use # or ## or ### for headers -- use CAPS instead
    • NEVER use **bold** or *italic* -- use CAPS or «guillemets» for emphasis
    • NEVER use ```code blocks``` -- just indent text
    • NEVER use [links](url) -- show raw URLs
    • For structured data, use indented key-value pairs or simple aligned columns:
        Account:   76561198012345678
        Name:      PlayerName
        Status:    Active
      For multi-row data, use simple spaced columns without box-drawing (boxes misalign easily):
        ACCOUNT              NAME         SHARED IPS  LAST SEEN
        76561198012345678    PlayerOne    3           2025-01-15
        76561198087654321    PlayerTwo    1           2024-11-03
    • For lists, use • bullets or numbered lists with plain digits (1. 2. 3.)
    • When showing Steam IDs, always include the profile link as a raw URL: https://steamcommunity.com/profiles/STEAMID64

    RESPONSE STRUCTURE
    Structure your final response in this order:
    1. Player profile (name, Steam ID, link)
    2. Shared IPs and related accounts (factual, no judgement yet)
    3. Activity pattern analysis (when accounts overlap or not)
    4. Chat behavior findings -- quote the exact offensive messages with timestamps
    5. VERDICT at the very end -- only after presenting ALL evidence
    Do NOT lead with dramatic conclusions like "STRONG EVIDENCE" before showing the data. Present facts first, conclude last.
    Always quote exact log lines as evidence. Never make claims about player behavior without showing the log lines that prove it.


    STEAM ID FORMATS
    There are three Steam ID formats:
    • Steam ID64: 76561198012345678 -- used by the database and all tools (search_alts, get_user, list_reservations, etc.)
    • Steam ID3: [U:1:52079950] -- used inside TF2 server log files
    • Old format: STEAM_0:0:26039975 -- legacy format, rarely seen in logs
    All Steam IDs in user messages have been pre-converted for you. They appear as: 76561198012345678 ([U:1:52079950])
    Use the Steam ID64 format when calling tools. Use the Steam ID3 format when searching reservation logs.
    NEVER attempt to convert between formats yourself -- the conversions provided are authoritative.

    INVESTIGATION RULES
    • Do NOT search reservation logs unless the admin specifically asks about chat behavior or specific in-game events. Log searching is slow.
    • When you do search logs, use specific search terms (player names, "say " for chat). Avoid broad single-character searches.
    • When searching logs for a specific player, use their Steam ID3 format ([U:1:X]) or their player name.
    • Log files are only available for reservations from the past 31 days. Do not attempt to search logs for older reservations.
    • Search ALL available reservations within the 31-day window. More data points give stronger evidence.

    LOG ANALYSIS RULES
    • NEVER paraphrase or summarize log data -- quote the exact log lines with timestamps.
    • Pay close attention to CONNECT and DISCONNECT events for both accounts. The key question is: did one account disconnect before or around the time the other connected?
    • Do NOT claim two accounts were "playing simultaneously" unless you can show log lines proving BOTH were actively in the server at the same overlapping timestamps.
    • NEVER fabricate or infer log entries that were not in the actual tool results. If the logs do not contain enough data to determine overlap, say so explicitly.

    LOG SEARCH TECHNIQUES
    • TF2 chat messages appear in logs as: "playername<uid><steamid><team>" say "message"
    • To find chat messages, search for "say " (with trailing space) as the search term. This returns ONLY chat lines, not kills/positions.
    • To find connect/disconnect events, search for "connected" or "disconnected".
    • Do NOT search for a player name alone -- that returns thousands of kill/damage/position lines and buries the important data.
    • Set max_results to 1000 when searching for chat behavior to ensure you capture all chat in the match.
  PROMPT

  ALLOWED_TOOLS = %w[
    search_alts
    search_by_asn
    get_user
    list_reservations
    search_reservation_logs
  ].freeze

  TOOL_LABELS = {
    "search_alts" => "Searching for alt accounts",
    "search_by_asn" => "Searching by ASN",
    "get_user" => "Looking up user",
    "list_reservations" => "Listing reservations",
    "search_reservation_logs" => "Searching reservation logs"
  }.freeze

  MAX_TOOL_ROUNDS = 15
  MAX_TOOL_RESULT_CHARS = 50_000

  STEAM_ID_PATTERN = /STEAM_[0-5]:[01]:\d+/i
  STEAM_ID3_PATTERN = /\[U:1:\d+\]/i
  STEAM_ID64_PATTERN = /\b(765\d{14})\b/

  def initialize(user:)
    @user = user
    @client = Anthropic::Client.new(
      api_key: Rails.application.credentials.dig(:anthropic, :api_key)
    )
  end

  def stream_response(messages:, &block)
    messages = normalize_steam_ids(messages)
    tool_definitions = build_tool_definitions
    rounds = 0

    loop do
      rounds += 1
      stop_reason, content_blocks = stream_and_collect(messages, tool_definitions, &block)

      break unless stop_reason == :tool_use

      tool_blocks = content_blocks.select { |b| b[:type] == "tool_use" }
      break if tool_blocks.empty?

      if rounds >= MAX_TOOL_ROUNDS
        # Hit round limit — force a final summary without tools
        messages << { role: "assistant", content: content_blocks }
        messages << { role: "user", content: [ { type: "text", text: "You have reached the tool call limit. Summarize your findings now with the data you have." } ] }
        stream_and_collect(messages, [], &block)
        break
      end

      # Add assistant message with all content blocks
      messages << { role: "assistant", content: content_blocks }

      # Execute tools and build results
      tool_results = tool_blocks.map do |tool_block|
        block.call(:tool_call, { id: tool_block[:id], label: tool_label(tool_block[:name], tool_block[:input]) })
        result = execute_tool(tool_block[:name], tool_block[:input])
        { type: "tool_result", tool_use_id: tool_block[:id], content: truncate_result(result.to_json) }
      end

      messages << { role: "user", content: tool_results }
    end
  end

  private

  def normalize_steam_ids(messages)
    messages.map do |msg|
      next msg unless msg[:role] == "user" && msg[:content].is_a?(String)

      content = msg[:content].dup
      converted = false

      # Convert STEAM_X:Y:Z to both formats
      content.gsub!(STEAM_ID_PATTERN) do |match|
        converted = true
        convert_to_both_formats(match)
      end

      # Convert [U:1:X] to both formats
      content.gsub!(STEAM_ID3_PATTERN) do |match|
        converted = true
        convert_to_both_formats(match)
      end

      # For bare Steam ID64, add the ID3 format (only if no other conversions produced ID64s)
      unless converted
        content.gsub!(STEAM_ID64_PATTERN) do |match|
          steam_id3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(match.to_i)
          "#{match} (#{steam_id3})"
        rescue StandardError
          match
        end
      end

      { role: msg[:role], content: content }
    end
  end

  def convert_to_both_formats(steam_id)
    steam_id64 = SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
    steam_id3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(steam_id64)
    "#{steam_id64} (#{steam_id3})"
  rescue StandardError
    steam_id
  end

  def stream_and_collect(messages, tool_definitions, &block)
    cached_messages = add_cache_breakpoint(messages)

    stream = @client.messages.stream_raw(
      model: "claude-haiku-4-5",
      max_tokens: 8192,
      system: [ { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } } ],
      messages: cached_messages,
      tools: tool_definitions
    )

    content_blocks = []
    current_block = nil
    stop_reason = nil

    stream.each do |event|
      case event
      when Anthropic::RawContentBlockStartEvent
        cb = event.content_block
        if cb.type == :text
          current_block = { type: "text", text: "" }
        elsif cb.type == :tool_use
          current_block = { type: "tool_use", id: cb.id, name: cb.name, input: "" }
        end

      when Anthropic::RawContentBlockDeltaEvent
        delta = event.delta
        if delta.type == :text_delta
          current_block[:text] += delta.text
          block.call(:token, delta.text)
        elsif delta.type == :input_json_delta
          current_block[:input] += delta.partial_json
        end

      when Anthropic::RawContentBlockStopEvent
        if current_block
          if current_block[:type] == "tool_use" && current_block[:input].is_a?(String)
            current_block[:input] = JSON.parse(current_block[:input]) rescue {} # rubocop:disable Style/RescueModifier
          end
          content_blocks << current_block
          current_block = nil
        end

      when Anthropic::RawMessageDeltaEvent
        stop_reason = event.delta.stop_reason
      end
    end

    [ stop_reason, content_blocks ]
  end

  def build_tool_definitions
    tools = ALLOWED_TOOLS.filter_map do |tool_name|
      tool_class = Mcp::ToolRegistry.find(tool_name)
      next unless tool_class

      {
        name: tool_class.tool_name,
        description: tool_class.description,
        input_schema: tool_class.input_schema
      }
    end
    # Cache breakpoint on last tool — tools + system are cached as a prefix
    tools[-1] = tools[-1].merge(cache_control: { type: "ephemeral" }) if tools.any?
    tools
  end

  def execute_tool(name, input)
    tool_class = Mcp::ToolRegistry.find(name)
    return { error: "Unknown tool: #{name}" } unless tool_class

    input = input.symbolize_keys if input.is_a?(Hash)
    tool = tool_class.new(@user)
    result = tool.execute(input)

    result = summarize_search_alts(result) if name == "search_alts" && result.is_a?(Hash) && result[:results]

    result
  rescue StandardError => e
    Rails.logger.error("[LeagueAdminAI] Tool #{name} error: #{e.message}")
    { error: e.message }
  end

  def summarize_search_alts(result)
    results = result[:results]
    target_uid = result[:target]

    # Batch-load proxy data for all IPs
    all_ips = results.map { |r| r[:ip] }.compact.uniq
    ip_lookups = IpLookup.where(ip: all_ips).index_by(&:ip)

    # Group by steam_uid to build per-account summaries
    by_account = results.group_by { |r| r[:steam_uid] }

    accounts = by_account.map do |uid, records|
      ips = records.map { |r| r[:ip] }.compact.uniq
      names = records.map { |r| r[:name] }.compact.uniq.first(5)
      reservations_with_dates = records.filter_map { |r|
        next unless r[:reservation_id]
        { id: r[:reservation_id], date: r[:reservation_starts_at] }
      }.uniq { |r| r[:id] }
      dates = records.map { |r| r[:reservation_starts_at] }.compact.sort
      asns = records.map { |r| { number: r[:asn_number], org: r[:asn_organization] } }.uniq.compact
      # Mark banned ASNs inline
      banned_asn_numbers = ReservationPlayer.banned_asns
      asns.each { |a| a[:banned] = true if a[:number] && banned_asn_numbers.include?(a[:number]) }

      # Pick the 5 most recent reservations, include dates so the model knows which are within log retention
      recent_reservations = reservations_with_dates.sort_by { |r| r[:date] || "" }.last(5)

      # Attach proxy/VPN data for this account's IPs (from IpLookup database)
      proxy_ips = ips.filter_map do |ip|
        lookup = ip_lookups[ip]
        next unless lookup&.is_proxy || lookup&.is_residential_proxy

        {
          ip: ip,
          is_proxy: lookup.is_proxy,
          is_residential_proxy: lookup.is_residential_proxy,
          fraud_score: lookup.fraud_score,
          isp: lookup.isp,
          country_code: lookup.country_code,
          false_positive: lookup.false_positive,
          is_banned: lookup.is_banned,
          ban_reason: lookup.ban_reason
        }
      end

      # Check IPs against ban list (CSV) and VPN range list
      banned_ips = ips.filter_map do |ip|
        reason = ReservationPlayer.banned_ip?(ip)
        next unless reason

        { ip: ip, reason: reason }
      end

      vpn_ips = ips.select { |ip| ReservationPlayer.vpn_ranges.any? { |range| range.include?(ip) } }

      # Check if this Steam UID is on the ban list
      uid_ban_reason = ReservationPlayer.banned_uid?(uid.to_i)

      account = {
        steam_uid: uid,
        names: names,
        is_target: uid == target_uid,
        shared_ips: ips.first(10),
        ip_count: ips.size,
        proxy_ips: proxy_ips,
        banned_ips: banned_ips,
        vpn_ips: vpn_ips,
        reservation_count: reservations_with_dates.size,
        recent_reservations: recent_reservations,
        first_seen: dates.first,
        last_seen: dates.last,
        asns: asns.compact.uniq
      }
      account[:banned_uid] = uid_ban_reason if uid_ban_reason

      account
    end

    # Sort: target first, then by reservation count descending
    accounts.sort_by! { |a| [ a[:is_target] ? 0 : 1, -a[:reservation_count] ] }

    # Keep target + accounts with 2+ shared reservations (1 reservation = just played in same game once)
    significant = accounts.select { |a| a[:is_target] || a[:reservation_count] >= 2 }
    noise_count = accounts.size - significant.size

    {
      target: target_uid,
      total_raw_records: results.size,
      unique_accounts: accounts.size,
      significant_accounts: significant.size,
      accounts_omitted_single_reservation: noise_count,
      accounts: significant,
      asn_info: result[:asn_info],
      stac_detections: result[:stac_detections]
    }
  end

  # Add cache_control to the last content block of the last message,
  # so the growing conversation prefix is cached between tool-use rounds.
  def add_cache_breakpoint(messages)
    return messages if messages.empty?

    msgs = messages.map(&:dup)
    last = msgs.last

    content = last[:content]
    if content.is_a?(String)
      msgs[-1] = last.merge(content: [ { type: "text", text: content, cache_control: { type: "ephemeral" } } ])
    elsif content.is_a?(Array) && content.any?
      new_content = content.map(&:dup)
      new_content[-1] = new_content[-1].merge(cache_control: { type: "ephemeral" })
      msgs[-1] = last.merge(content: new_content)
    end

    msgs
  end

  def truncate_result(json_string)
    return json_string if json_string.length <= MAX_TOOL_RESULT_CHARS

    truncated = json_string[0, MAX_TOOL_RESULT_CHARS]
    "#{truncated}\n\n[TRUNCATED — result was #{json_string.length} characters, showing first #{MAX_TOOL_RESULT_CHARS}]"
  end

  def tool_label(name, input)
    label = TOOL_LABELS[name] || name
    detail = format_tool_detail(input)
    detail.present? ? "#{label}: #{detail}" : label
  end

  def format_tool_detail(input)
    return nil unless input.is_a?(Hash)

    parts = []
    parts << (input["steam_uid"] || input[:steam_uid]) if (input["steam_uid"] || input[:steam_uid]).present?
    parts << (input["query"] || input[:query]) if (input["query"] || input[:query]).present?
    parts << "IP #{input["ip"] || input[:ip]}" if (input["ip"] || input[:ip]).present?
    parts << (input["asn_number"] || input[:asn_number]).to_s if (input["asn_number"] || input[:asn_number]).present?
    parts << "reservation ##{input["reservation_id"] || input[:reservation_id]}" if (input["reservation_id"] || input[:reservation_id]).present?
    parts << "\"#{input["search_term"] || input[:search_term]}\"" if (input["search_term"] || input[:search_term]).present?
    parts.join(", ").presence
  end
end
