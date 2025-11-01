# typed: false

require "openai"

class AiCommandHandler
  attr_reader :reservation

  REDIS_CONTEXT_TTL = 1.hour
  MAX_CONTEXT_HISTORY = 10

  MAP_SEARCH_TOOL = {
    type: "function",
    function: {
      name: "find_maps",
      description: "Search for TF2 maps based on a query string. Returns a ranked list of matching map names.",
      parameters: {
        type: :object,
        properties: { query: { type: :string, description: "The search query for map names (e.g., 'koth nucleus', 'pl_badwater')." } },
        required: [ "query" ]
      }
    }
  }.freeze

  COMMAND_SEARCH_TOOL = {
    type: "function",
    function: {
      name: "find_server_commands",
      description: "Search for commands and settings, use a single word as the query. Prefer shortest word possible. Use '.' as the query to list all available commands and cvars.",
      parameters: {
        type: :object,
        properties: { query: { type: :string, description: "Query is a single word, use shortest word possible, for commands or cvars (e.g., 'mp_timelimit', 'kick'). Use '.' to list everything." } },
        required: [ "query" ]
      }
    }
  }.freeze

  RESERVATION_TOOL = {
    type: "function",
    function: {
      name: "modify_reservation",
      description: "Modify the server reservation. Can be used to end the reservation, extend it, lock/unlock the server, or unban all players.",
      parameters: {
        type: :object,
        properties: {
          action: { type: :string, enum: [ "end", "extend", "lock", "unlock", "unbanall" ], description: "The action to perform: 'end' the reservation, 'extend' it, 'lock' the server (prevents new players from joining), 'unlock' it, or 'unbanall' to remove all bans." }
        },
        required: [ "action" ]
      }
    }
  }.freeze

  SUBMIT_ACTION_TOOL = {
    type: "function",
    function: {
      name: "submit_server_action",
      description: "Submits the final server command(s) and user response after processing the request.",
      parameters: {
        type: :object,
        properties: {
          command: { type: [ :string, :null ], description: "The rcon command(s) to execute, separated by semicolons. Null if no command should run." },
          response: { type: :string, description: "The message to display to the user in chat." },
          success: { type: :boolean, description: "True if the request was successfully processed, False otherwise (e.g., needs clarification)." }
        },
        required: [ "command", "response", "success" ]
      }
    }
  }.freeze

  AVAILABLE_TOOLS = [ MAP_SEARCH_TOOL, COMMAND_SEARCH_TOOL, RESERVATION_TOOL, SUBMIT_ACTION_TOOL ].freeze

  def initialize(reservation)
    @reservation = reservation
  end

  def process_request(request)
    begin
      Rails.logger.info("[AI ##{reservation&.id || 'N/A'}] Processing request: #{request}")
      messages = build_openai_messages(request)
      result = call_openai_and_handle_tools(messages)
      process_ai_result(result, request)
      result
    rescue JSON::ParserError, NoMethodError => e
      Rails.logger.error("[AI ##{reservation&.id || 'N/A'}] Error processing AI response structure: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { "success" => false, "response" => "Sorry, I had trouble understanding the AI's response format. Please try again.", "command" => nil }
    rescue StandardError => e
      Rails.logger.error("[AI ##{reservation&.id || 'N/A'}] General error processing AI request: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { "success" => false, "response" => "An unexpected error occurred. Please try again.", "command" => nil }
    end
  end

  private

  def server_status
    reservation.server.rcon_exec("status;mp_tournament_whitelist;sv_gravity;sv_cheats;mp_timelimit;mp_winlimit;mp_windifference;tf_weapon_criticals;host_timescale;sv_password;tv_status;sm plugins list;tftrue_whitelist_id").gsub(/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/, "0.0.0.0")
  end

  def get_previous_context
    return unless reservation
    key = "ai_context_history:#{reservation.id}"
    Rails.cache.read(key) || []
  end

  def save_context(request, result)
    return unless reservation && result && result["success"]
    key = "ai_context_history:#{reservation.id}"

    history = Rails.cache.read(key) || []
    history.push({
      "request" => request,
      "response" => result["response"],
      "command" => result["command"]
    })
    history = history.last(MAX_CONTEXT_HISTORY)

    Rails.cache.write(key, history, expires_in: REDIS_CONTEXT_TTL)
  end

  def system_prompt(reservation)
    <<~PROMPT
    You are a serveme.tf's TF2 server assistant that converts user requests into server commands. Respond in Genuine People Personalities style (Hitchhiker's Guide). No emojis/special chars.

    Your primary goal is to determine the correct rcon command(s), a response message for the user, and whether the operation was successful.
    Use the available tools ('find_maps', 'find_server_commands') if you need more information to fulfill the request.
    You can also use the 'modify_reservation' tool to end the reservation immediately or extend it if requested by the user.

    Once you have determined the final command(s) and response message, you MUST use the 'submit_server_action' tool to provide the result.
    If you use the 'modify_reservation' tool, you should still use 'submit_server_action' afterwards to confirm the outcome to the user.
    Do NOT output raw JSON or any text outside of the tool call for the final response.
    Even if the request is purely informational and requires no command (i.e., command should be null), you must still use the 'submit_server_action' tool to provide the informative response.

    Example Refusal: If asked "make me admin", use the tool with command: null, response: "Sorry, I cannot grant admin privileges.", success: false.

    Example Command: If asked to "add 6 easy blue scouts", use the tool with command: "mp_autoteambalance 0; mp_teams_unbalance_limit 0; tf_bot_add 6 scout blue easy", response: "Okay, adding 6 easy blue scouts.", success: true.

    'submit_server_action' tool parameters:
    - command: RCON command(s) separated by semicolons, or null if no command should be run.
    - response: The message to display to the user in chat.
    - success: Boolean indicating if the request was successfully understood and translated into a command (or determined no command was needed).

    Command Syntax:
    - Multiple commands: separate with semicolon
    - SM commands: prefix userids from rcon status with "#", requires sourcemod plugin to be loaded
    - Targets for SM commands:
      - player: #userid-of-player-from-rcon-status (e.g. sm_rename #123 "John Doe")
      - groups: @all @bots @alive @dead @humans (e.g. sm_slay @alive)
      - teams: @red @blue (e.g. sm_rename @red "Boys in Red")

    Standard player counts:
    - 4 players: ultiduo
    - 8 players: 4s, pass time
    - 12 players: 6v6/6s
    - 18 players: 9v9/highlander/hl
    - 24 players: 12v12/12s

    Default team compositions:
    - ultiduo: 1 medic, 1 soldier
    - ultitrio: 1 medic, 1 soldier, 1 scout
    - 6s: 2 scouts, 2 soldiers, 1 demoman, 1 medic
    - highlander: 1 medic, 1 soldier, 1 demoman, 1 scout, 1 engineer, 1 heavyweapons, 1 pyro, 1 spy, 1 sniper
    - pass time class limits: max 3 soldiers, 1 medic, 1 demoman

    The SourceTV bot should not be taken into account for player counts, other bots do count.

    Chat Commands:
    sm_say/chat/csay/hsay <msg> - All players (chat/admin-only/center/hint)
    sm_tsay [color] <msg> - Top-left dialog (colors: White Red Green Blue Yellow Purple Cyan Orange Pink Olive Lime Violet Lightblue)
    sm_psay <target> <msg> - Private message

    Maps per league and gamemode:
    #{LeagueMaps.grouped_league_maps.map { |l| "#{l.name}: #{l.maps.join(' ')}" }.join("\n")}

    Special modes:
    - MGE for 1v1 practice. Maps: mge_chillypunch_final4_fix2 mge_training_v8_beta4b mge_oihguv_sucks_a12
    - BBall 2v2. Map: ctf_ballin_sky
    - Ultiduo 2v2. Map: koth_ultiduo_r_b7 ultiduo_baloo_v2 ultiduo_grove_b4 ultiduo_lookout_b1 ultiduo_cooked_rc2 ultiduo_process_f10 ultiduo_babty_f3
    - Ultitrio 3v3. Map: ultitrio_caffapro_b6 ultitrio_bound_rc1b ultitrio_aesthetic_b9 ultitrio_staten_rc1 ultitrio_dockport_final6 ultitrio_eruption_v6 ulti_fira_b2a

    When changing maps and modes try to execute a relevant config before changing the map, prefer a league map over an exact match to what was requested.
    Don't change the map if only a config change was requested. Don't exec configs if a single variable change was requested, configs contain many variables and would override the requested change.

    Map prefixes:
      cp_ (control points, use configs ending in _5cp)
      koth_ (king of the hill, use configs ending in _koth)
      pl_ (payload, use configs ending in _stopwatch)
      ctf_ (capture the flag, use configs ending in _ctf)
      pass_ (PASS time, use configs ending in _pt, or starting with pass_ or pt_)

    Regions and biggest league in each region, current region #{SITE_HOST}. Include the region's league to select the best matching maps and configs:
    - serveme.tf: etf2l
    - na.serveme.tf: rgl
    - sea.serveme.tf: afc
    - au.serveme.tf: ozfortress/ozf

    Available configs: #{ServerConfig.active.ordered.map(&:file).join(" ")}
    Available item/weapon whitelists: #{Whitelist.active.ordered.map(&:file).join(" ")}
    Special item/weapon whitelists using tftrue_whitelist_id: allow_everything, block_everything

    Class and team names for tf_bot commmands, use these exactly:
      Classes: demoman, engineer, heavyweapons, medic, pyro, scout, soldier, sniper, spy.
      Teams: red, blue

    Commands:
    - changelevel <map>
    - exec <config>
    - mp_tournament_whitelist cfg/<file>
    - tftrue_whitelist_id [number-or-friendly-name]
    - kickid <userid> [msg]
    - banid 0 <userid> kick
    - mp_tournament 0/1
    - sm_slap/sm_slay <target>
    - mp_autoteambalance 0/1
    - mp_restartgame
    - mp_restartround
    - mp_teams_unbalance_limit 0/1
    - mp_friendlyfire 0/1
    - mp_scrambleteams
    - mp_forcewin
    - mp_switchteams
    - mp_forcerespawnplayers
    - mp_disable_respawn_times 0/1 (combine with sm_cvar spec_freeze_time 0 for instant respawn)
    - tf_playergib 0/1/2 (2 is highest gib chance)
    - tf_forced_holiday 0/1/2/3 Forces the server to have holidays (0= none, 1= Birthday, 2= Halloween, default none)
    - tf_bot_add [count] [class] [team] [difficulty] [name] (difficulty can be easy, normal, hard, or expert)
    - tf_bot_difficulty [difficulty] (difficulty can be 0=easy, 1=normal, 2=hard, 3=expert)
    - sm_rename <target> name
    - sm_blind <target> 0/240/255 (0=none, 240=medium, 255=full)
    - sm_gag <target> (chat)
    - sm_silence <target> (voice+chat)
    - sm_mute <target> (voice)
    - sm_unmute <target> (voice)
    - sm_drug <target> 0/1 messes with vision of player
    - sm_freezebomb <target> 0/1
    - sm_freeze <target> [time]
    - sm_firebomb <target> 0/1
    - sm_burn <target> [time]
    - sm_timebomb <target> 0/1
    - sm_beacon <target> 0/1
    - sm_vote "question?" "Answer1 "Answer2" ... "Answer5"
    - sm_voteban <player> "reason"
    - sm_votekick <player> "reason"
    - sm_votemap <mapname> [mapname2] ... [mapname5]
    - _restart (full server restart to revert all changes, causes players to disconnect, only use this command after confirmation by the user)

    Tournament Class Limits:
    - tf_tournament_classlimit_<class> [count] (classes: scout, soldier, pyro, demoman, heavy, engineer, medic, sniper, spy)

    SourceTV Settings:
    - tv_delay [delay]
    - tv_delaymapchange 1

    Match Settings:
    - mp_maxrounds [rounds]
    - mp_timelimit [minutes]
    - mp_windifference [rounds]
    - mp_winlimit [rounds]
    - mp_tournament 0/1
    - mp_tournament_restart
    - mp_tournament_stopwatch 0/1
    - mp_match_end_at_timelimit 0/1
    - round_time_override [seconds]
    - mp_bonusroundtime [seconds]
    - mp_respawnwavetime 10.0
    - mp_stalemate_enable 0/1
    - mp_teams_unbalance_limit 0
    - mp_tournament_allow_non_admin_restart 0/1
    - mp_friendlyfire 0/1
    - mp_highlander 0/1
    - round_time_override [seconds] The length (in seconds) of the round timer on 5CP and KOTH. -1 Default gametype behavior (default)
    - sm_cvar spec_freeze_time [seconds] (default 4)

    Gameplay Settings:
    - tf_damage_disablespread 0/1 disables variable damage
    - tf_use_fixed_weaponspreads 0/1 used fixed pattern for weapons that fire pellets, e.g. scattergun, shotgun
    - tf_weapon_criticals 0/1
    - tf_preround_push_from_damage_enable 0/1
    - tf_avoidteammates_pushaway 0/1
    - tf_clamp_airducks 0/1
    - tf_enable_glows_after_respawn 0/1
    - tf_spawn_glows_duration [seconds]
    - tf_dropped_weapon_lifetime [seconds]
    - tf_birthday_ball_chance [percentagee]
    - sv_gravity 800 (800 = default)
    - sv_pausable 0/1
    - sv_allow_votes 0/1
    - sv_allow_wait_command 0/1
    - sv_alltalk 0/1
    - sv_cheats 0/1

    Competitive Fixes:
    - sm_inhibit_extendfreeze 0/1
    - sm_projectiles_ignore_teammates 0/1
    - sm_prevent_respawning 0/1
    - sm_remove_medic_attach_speed 0/1
    - sm_concede_command 0/1

    Bot Commands:
    - tf_bot_add [count] [class] [team] [difficulty] [name]
    - tf_bot_difficulty [0=easy/1=normal/2=hard/3=expert]
    - tf_bot_kick [BOT name/all]
    - tf_bot_force_class [class]
    - tf_bot_keep_class_after_death 0/1
    - tf_bot_prefix_name_with_difficulty 0/1
    - tf_bot_melee_only 0/1
    - tf_bot_force_jump 0/1 (cheat)
    - tf_bot_fire_weapon_allowed 0/1
    - tf_bot_flag_kill_on_touch 0/1
    - tf_bot_warp_team_to_me
    - tf_bot_quota [count]
    - tf_bot_quota_mode [normal/fill/match]

    Special Commands:
    - tf_medieval 0/1 (Requires map change)
    - tf_always_loser 0/1 (cheat)
    - tf_damage_multiplier_blue -1.0/1.0 (cheat). e.g. 1.0 = 100% damage, 0.1 = 10% damage. -0.1 = 10% heal, -1.0 = 100% heal.
    - tf_damage_multiplier_red -1.0/1.0 (cheat)

    Local player commands, if these are requested tell players to enter the command themselves in their TF2 console, you can't use these as an rcon command:
    - noclip (allows player to fly and pass through walls, cheat)
    - hurtme (allows player to hurt themselves or with a negative value heal themselves for near infinite health, cheat)
    - Spawning bosses with ent_create <entity> (e.g. eyeball_boss headless_hatman tank_boss merasmus tf_robot_destruction_robot tf_zombie, cheat)
    - Readying up a team or player

    If the server is on sv_cheats 0, and a command requires sv_cheats 1, prefix it to the beginning of the commands.
    Only change sv_cheats for commands that require it.

    If the command adds bots, prefix with "mp_autoteambalance 0; mp_teams_unbalance_limit 0".
    e.g. "mp_autoteambalance 0; mp_teams_unbalance_limit 0; tf_bot_add 6 heavyweapons blue easy"

    Reservation Time Management:
    - Use the 'modify_reservation' tool with action 'end' for requests like "end the server now".
    - Use the 'modify_reservation' tool with action 'extend' for requests like "add more time" or "extend the server". The standard extension duration will be applied.

    Server Access Control:
    - Use the 'modify_reservation' tool with action 'lock' for requests like "lock the server" or "keep people out". This changes the password and bans new players if they join.
    - Use the 'modify_reservation' tool with action 'unlock' for requests like "unlock the server". This restores the original password.
    - Use the 'modify_reservation' tool with action 'unbanall' for requests like "unban everyone" or "remove all bans".

    Split responses >200 chars (applies to the 'response' field in the tool call). Always try to respond, but only for TF2 related questions, validate inputs.
    Only execute a command if you're sure it matches the player's request, else ask for clarification using the 'submit_server_action' tool with success: false and an appropriate response message.
    PROMPT
  end

  def build_openai_messages(request)
    messages = []
    messages << { role: "system", content: system_prompt(reservation) }

    history = get_previous_context
    history.each do |ctx|
      messages << { role: "user", content: ctx["request"] }
      messages << { role: "assistant", content: "replied: #{ctx['response']}\ncommand: #{ctx['command']}" }
    end

    messages << {
      role: "system",
      content: "Current Server Status (all IP addresses hidden for privacy):\n#{server_status}"
    }

    messages << { role: "user", content: request }
    messages
  end

  def call_openai_and_handle_tools(messages)
    response = OpenaiClient.chat({
      messages: messages,
      reasoning_effort: "minimal",
      tools: AVAILABLE_TOOLS,
      tool_choice: "required"
    })

    message = response.dig("choices", 0, "message")

    if message["tool_calls"]
      tool_call = message["tool_calls"][0] # Assuming one tool call per response for now
      function_name = tool_call.dig("function", "name")
      arguments_json = tool_call.dig("function", "arguments")

      begin
        arguments = JSON.parse(arguments_json)
      rescue JSON::ParserError => e
        return handle_argument_parse_error(function_name, arguments_json, e)
      end

      messages << message

      case function_name
      when "submit_server_action"
        handle_submit_action(arguments)
      when "find_maps", "find_server_commands", "modify_reservation"
        handle_intermediate_tool(messages, tool_call, function_name, arguments)
      else
        handle_unknown_tool(function_name)
      end

    elsif message["content"]
      handle_unexpected_content(message["content"])
    else
      handle_empty_response(response)
    end
  end

  def handle_submit_action(arguments)
    {
      "command" => arguments["command"],
      "response" => arguments["response"],
      "success" => arguments["success"]
    }
  end

  def handle_intermediate_tool(messages, tool_call, function_name, arguments)
    Rails.logger.info("[AI ##{reservation.id}] Calling tool '#{function_name}' with arguments: #{arguments.inspect}")
    tool_result_content = perform_tool_action(function_name, arguments)

    messages << {
      role: "tool",
      tool_call_id: tool_call["id"],
      name: function_name,
      content: tool_result_content.to_json
    }

    final_response = OpenaiClient.chat({
      messages: messages,
      tools: AVAILABLE_TOOLS, # Still provide all tools
      reasoning_effort: "minimal",
      tool_choice: { type: "function", function: { name: "submit_server_action" } } # Force the final tool
    })

    final_message = final_response.dig("choices", 0, "message")

    if final_message["tool_calls"] && final_message.dig("tool_calls", 0, "function", "name") == "submit_server_action"
      final_tool_call = final_message["tool_calls"][0]
      final_arguments_json = final_tool_call.dig("function", "arguments")
      begin
        final_arguments = JSON.parse(final_arguments_json)
        handle_submit_action(final_arguments)
      rescue JSON::ParserError => e
        handle_argument_parse_error("submit_server_action", final_arguments_json, e, after_intermediate: true)
      end
    else
      handle_missing_submit_tool_error(final_message)
    end
  end

  def perform_tool_action(function_name, arguments)
    case function_name
    when "find_maps"
      perform_map_search(arguments)
    when "find_server_commands"
      perform_command_search(arguments)
    when "modify_reservation"
      perform_reservation_modification(arguments)
    else
      Rails.logger.error("[AI ##{reservation.id}] Unknown action requested in perform_tool_action: #{function_name}")
      { error: "Unknown tool action" } # Return an error indicator
    end
  end

  def perform_map_search(arguments)
    map_query = arguments["query"]
    search_results = MapSearchService.new(map_query).search
    { maps: search_results }
  end

  def perform_command_search(arguments)
    command_query = arguments["query"]
    safe_query = command_query.gsub(/[^\w\.\-\*\s]/, "").strip
    find_command = "find \"#{safe_query}\""
    command_results = reservation.server.rcon_exec(find_command)
    { results: command_results }
  end

  def perform_reservation_modification(arguments)
    action = arguments["action"]
    begin
      case action
      when "end"
        if reservation.end_reservation
          { success: true, message: "Reservation ended successfully." }
        else
          { success: false, message: "Could not end the reservation." }
        end
      when "extend"
        extension_duration = reservation.user&.reservation_extension_time || 30.minutes
        if reservation.extend!
          { success: true, message: "Reservation extended by #{extension_duration / 60} minutes." }
        else
          { success: false, message: "Could not extend the reservation. Is it already at maximum duration?" }
        end
      when "lock"
        reservation.lock!
        reservation.status_update("Server locked via AI command, password changed and no new connects allowed")
        { success: true, message: "Server locked. Password changed and no new connections allowed." }
      when "unlock"
        if reservation.unlock!
          reservation.server.rcon_say "Server unlocked, original password restored!"
          reservation.status_update("Server unlocked via AI command")
          { success: true, message: "Server unlocked. Original password restored." }
        else
          { success: false, message: "Server is not currently locked." }
        end
      when "unbanall"
        result = reservation.unban_all!
        if result[:count].nil?
          { success: false, message: result[:message] }
        else
          reservation.status_update("#{result[:message]} via AI command") if result[:count] > 0
          { success: true, message: result[:message] }
        end
      else
        Rails.logger.error("[AI ##{reservation.id}] Unknown action requested in modify_reservation: #{action}")
        { success: false, message: "Internal error: Unknown reservation action requested." }
      end
    rescue StandardError => e
      Rails.logger.error("[AI ##{reservation.id}] Error during reservation modification (#{action}): #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { success: false, message: "An error occurred while trying to #{action} the reservation." }
    end
  end

  def handle_argument_parse_error(function_name, json, error, after_intermediate: false)
    context = after_intermediate ? "final submit_server_action call" : "tool '#{function_name}'"
    Rails.logger.error("[AI ##{reservation&.id || 'N/A'}] Failed to parse arguments for #{context}: #{error.message}. Arguments JSON: #{json.inspect}")
    { "success" => false, "response" => "Internal error processing AI tool arguments.", "command" => nil }
  end

  def handle_unknown_tool(function_name)
    Rails.logger.error("[AI ##{reservation.id}] Requested unknown tool: #{function_name}")
    { "success" => false, "response" => "Internal error: AI requested an unknown tool.", "command" => nil }
  end

  def handle_missing_submit_tool_error(final_message)
    Rails.logger.error("[AI ##{reservation.id}] Failed to use 'submit_server_action' tool after intermediate tool call. Response message: #{final_message.inspect}")
    { "success" => false, "response" => "AI failed to provide a structured final response. Please try again.", "command" => nil }
  end

  def handle_unexpected_content(content)
    Rails.logger.error("[AI ##{reservation.id}] Responded with text instead of using 'submit_server_action' tool. Content: #{content.inspect}")
    { "success" => false, "response" => "AI response format error. It should have used a tool.", "command" => nil }
  end

  def handle_empty_response(response)
     Rails.logger.error("[AI ##{reservation.id}] Response had neither content nor tool calls. Full response: #{response.inspect}")
     { "success" => false, "response" => "AI returned an empty or invalid response.", "command" => nil }
  end

  def process_ai_result(result, request)
    Rails.logger.info("[AI ##{reservation.id}] Processed result: #{result.inspect}")

    is_valid_command = false
    final_response_to_send = result["response"]

    if result["success"] && result["command"].present?
      if CommandValidator.validate(result["command"])
        is_valid_command = true
      else
        Rails.logger.error("[AI ##{reservation.id}] Proposed disallowed command: #{result['command']}")
        final_response_to_send = "Sorry, I can't run that command as parts of it might not be allowed."
        result["success"] = false
        result["command"] = nil
      end
    end

    if final_response_to_send.present?
      reservation&.server&.rcon_say(final_response_to_send)
    end

    if is_valid_command
      sleep 1 if Rails.env.production?
      Rails.logger.info("[AI ##{reservation.id}] Executing validated command: #{result['command']}")
      reservation&.server&.rcon_exec(result["command"])
    end

    result["response"] = final_response_to_send
    save_context(request, result) if result["success"]
  end
end
