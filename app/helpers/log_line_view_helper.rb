# typed: false
# frozen_string_literal: true

module LogLineViewHelper
  extend T::Sig
  include ERB::Util

  # Type alias for the formatted hash from LogLineFormatter
  FormattedLogLine = T.type_alias { T::Hash[Symbol, T.untyped] }

  # Team colors matching TF2 style
  TEAM_COLORS = {
    "red" => "#BD3B3B",
    "blue" => "#5885A2",
    "spectator" => "#888888",
    "unassigned" => "#888888",
    "" => "#888888"
  }.freeze

  # Sentry kills - show engineer class icon
  SENTRY_WEAPONS = %w[obj_sentrygun obj_sentrygun2 obj_sentrygun3 obj_minisentry tf_projectile_sentryrocket].freeze

  # TF2 class names mapping to icon filenames
  CLASS_ICONS = %w[scout soldier pyro demoman heavyweapons engineer medic sniper spy].freeze

  # Weapons with specific backstab icons (use #{weapon}_backstab instead of generic backstab)
  BACKSTAB_VARIANTS = %w[big_earner kunai conniver_kunai spy_cicle sharp_dresser voodoo_pin].freeze

  # Weapons with specific headshot icons (use #{weapon}_headshot instead of weapon + HS badge)
  HEADSHOT_VARIANTS = %w[ambassador huntsman huntsman_flyingburn deflect_huntsman deflect_huntsman_flyingburn].freeze

  # Sniper rifles that should use the generic headshot icon
  SNIPER_RIFLES = %w[sniperrifle awper_hand bazaar_bargain machina the_classic pro_rifle shooting_star].freeze

  # Map projectile/alternate weapon names to their icon names
  WEAPON_ALIASES = {
    "tf_projectile_arrow" => "huntsman",
    "tf_projectile_arrow_fire" => "huntsman_flyingburn",
    # Projectile class names
    "tf_projectile_flare" => "flaregun",
    "tf_projectile_healing_bolt" => "crusaders_crossbow",
    "tf_projectile_sentryrocket" => "obj_sentrygun",
    "tf_weapon_grenadelauncher" => "tf_projectile_pipe",
    # Gas/jar variants
    "jar_gas" => "gas_blast",
    # Environmental/fallback
    "unknown" => "skull",
    "prop_physics" => "skull"
  }.freeze

  sig { params(class_name: T.nilable(String)).returns(T.any(String, ActiveSupport::SafeBuffer)) }
  def class_icon(class_name)
    return "" unless class_name.present?

    class_lower = class_name.downcase
    return "" unless class_lower.in?(CLASS_ICONS)

    tag.span("", class: "class-icon class-icon-#{class_lower}", role: "img", title: class_name, aria: { label: class_name })
  end

  sig { params(weapon_name: T.nilable(String)).returns(ActiveSupport::SafeBuffer) }
  def weapon_icon(weapon_name)
    weapon_lower = weapon_name&.downcase || "default"

    # CSS classes from _killicons.css.scss handle positioning
    # .killicon provides the base sprite styling
    # .killicon-{weapon} provides the specific position and dimensions
    content_tag(:span, "", class: "killicon killicon-#{weapon_lower}", title: weapon_name || "unknown")
  end

  sig { params(player: T.nilable(TF2LineParser::Player), link: T::Boolean, league_request_link: T::Boolean).returns(ActiveSupport::SafeBuffer) }
  def log_player_name(player, link: true, league_request_link: false)
    return content_tag(:span, "Unknown", class: "player-name team-unassigned") unless player

    team_class = player.team&.downcase || "unassigned"
    name = h(player.name)

    if link && player.steam_id
      steam_uid = LogLineFormatter.steam_id_to_community_id(player.steam_id)
      if steam_uid
        if league_request_link
          link_to name, league_request_path(steam_uid: steam_uid, cross_reference: true),
            class: "player-name team-#{team_class}",
            target: "_blank",
            rel: "noopener noreferrer",
            title: "#{player.steam_id} (#{steam_uid})"
        else
          steam_url = "https://steamcommunity.com/profiles/#{steam_uid}"
          link_to name, steam_url,
            class: "player-name team-#{team_class}",
            target: "_blank",
            rel: "noopener noreferrer",
            title: player.steam_id
        end
      else
        content_tag(:span, name, class: "player-name team-#{team_class}")
      end
    else
      content_tag(:span, name, class: "player-name team-#{team_class}")
    end
  end

  sig { params(time: T.nilable(Time)).returns(ActiveSupport::SafeBuffer) }
  def log_timestamp(time)
    return content_tag(:span, "", class: "log-timestamp") unless time

    content_tag(:span, time.strftime("%H:%M:%S"),
      class: "log-timestamp",
      title: time.strftime("%Y-%m-%d %H:%M:%S"))
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_kill_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    attacker = event.player
    victim = event.target
    weapon = event.respond_to?(:weapon) ? event.weapon : nil
    customkill = event.respond_to?(:customkill) ? event.customkill : nil
    weapon_lower = weapon&.downcase

    # Normalize projectile names to their weapon icon names
    weapon_lower = WEAPON_ALIASES[weapon_lower] || weapon_lower

    # Use weapon-specific backstab/headshot icons when available
    if customkill == "backstab"
      weapon = if weapon_lower.in?(BACKSTAB_VARIANTS)
        # Map conniver_kunai to kunai_backstab
        base = weapon_lower == "conniver_kunai" ? "kunai" : weapon_lower
        "#{base}_backstab"
      else
        "backstab"
      end
    elsif customkill == "headshot"
      weapon = if weapon_lower.in?(HEADSHOT_VARIANTS)
        "#{weapon_lower}_headshot"
      elsif weapon_lower.in?(SNIPER_RIFLES)
        "headshot"
      else
        weapon_lower
      end
    else
      weapon = weapon_lower
    end

    modifier = if customkill.present?
      case customkill
      when "headshot"
        # Only show HS badge if we didn't use a headshot-specific icon
        unless weapon_lower.in?(HEADSHOT_VARIANTS) || weapon_lower.in?(SNIPER_RIFLES)
          content_tag(:span, "HS", class: "kill-modifier headshot", title: "Headshot")
        end
      when /^taunt/
        content_tag(:span, "🎭", class: "kill-modifier taunt", title: "Taunt Kill")
      when "bleed"
        content_tag(:span, "🩸", class: "kill-modifier bleed", title: "Bleed")
      when "burning"
        content_tag(:span, "🔥", class: "kill-modifier burning", title: "Afterburn")
      when "reflected"
        content_tag(:span, "↩️", class: "kill-modifier reflected", title: "Reflected")
      when "gib"
        content_tag(:span, "💥", class: "kill-modifier gib", title: "Gibbed")
      end
    end

    content = safe_join([
      log_player_name(attacker),
      weapon_icon(weapon),
      modifier,
      log_player_name(victim)
    ].compact)

    content_tag(:span, content, class: "log-kill")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_chat_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:message)

    team_prefix = formatted[:type] == :team_say ? "(TEAM) " : ""

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, ": ", class: "chat-separator"),
      content_tag(:span, "#{team_prefix}#{event.message}", class: "chat-message")
    ])

    content_tag(:span, content, class: "log-chat")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_connect_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    admin_mode = formatted[:admin] == true

    # Use formatted[:message] which is sanitized based on skip_sanitization flag
    if formatted[:message].present?
      ip_address = formatted[:message].to_s.split(":").first
      if admin_mode && ip_address.present? && ip_address != "0.0.0.0"
        ip_link = link_to(formatted[:message], league_request_path(ip: ip_address, cross_reference: true),
          class: "ip-address-link", target: "_blank", rel: "noopener noreferrer")
        address_text = safe_join([ " from ", ip_link ])
      else
        address_text = " from #{formatted[:message]}"
      end
    else
      address_text = ""
    end

    content = safe_join([
      log_player_name(event.player, league_request_link: admin_mode),
      content_tag(:span, " connected", class: "connect-action"),
      address_text
    ])

    content_tag(:span, content, class: "log-connect")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_disconnect_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    reason = event.respond_to?(:message) ? " (#{event.message})" : ""

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " disconnected#{reason}", class: "disconnect-action")
    ])

    content_tag(:span, content, class: "log-disconnect")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_point_capture_event(formatted)
    event = formatted[:event]
    cap_name = format_cap_name(event)
    team = event.respond_to?(:team) ? event.team : nil

    if event.respond_to?(:player) && event.player
      content = safe_join([
        log_player_name(event.player),
        content_tag(:span, " captured #{cap_name}", class: "capture-action")
      ])
    elsif team
      team_class = team.downcase
      content = safe_join([
        content_tag(:span, team, class: "player-name team-#{team_class}"),
        content_tag(:span, " captured #{cap_name}", class: "capture-action")
      ])
    else
      return content_tag(:span, formatted[:raw], class: "log-content")
    end

    content_tag(:span, content, class: "log-capture")
  end

  sig { params(event: TF2LineParser::Events::Event).returns(String) }
  def format_cap_name(event)
    return event.cap_name.to_s if event.cap_name.present?
    return "point #{event.cap_number}" if event.cap_number.present?

    "control point"
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_round_event(formatted)
    event = formatted[:event]
    message = case formatted[:type]
    when :round_win
      team = event.respond_to?(:team) ? event.team : "a team"
      "Round won by #{team}"
    when :round_start
      "Round started"
    when :round_stalemate
      "Round ended in stalemate"
    when :current_score
      if event.respond_to?(:team) && event.respond_to?(:score)
        "#{event.team}: #{event.score}"
      else
        formatted[:raw]
      end
    when :final_score
      if event.respond_to?(:team) && event.respond_to?(:score)
        "Final - #{event.team}: #{event.score}"
      else
        formatted[:raw]
      end
    when :match_end
      "Match ended"
    when :round_length
      if event.respond_to?(:length)
        seconds = event.length.to_f
        mins = (seconds / 60).floor
        secs = (seconds % 60).round
        "Round length: #{mins}:#{secs.to_s.rjust(2, '0')}"
      else
        formatted[:raw]
      end
    else
      formatted[:raw]
    end

    content_tag(:span, message, class: "log-round")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_console_event(formatted)
    message = formatted[:message] || formatted[:raw]

    content = safe_join([
      content_tag(:span, "Console: ", class: "console-prefix"),
      content_tag(:span, message, class: "console-message")
    ])

    content_tag(:span, content, class: "log-console")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_suicide_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    weapon = event.respond_to?(:weapon) ? event.weapon : nil

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " suicided", class: "suicide-action"),
      weapon.present? ? safe_join([ " with ", weapon_icon(weapon) ]) : ""
    ])

    content_tag(:span, content, class: "log-suicide")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_rcon_event(formatted)
    message = formatted[:message] || formatted[:raw]

    content = safe_join([
      content_tag(:span, "RCON: ", class: "rcon-prefix"),
      content_tag(:span, message, class: "rcon-message")
    ])

    content_tag(:span, content, class: "log-rcon")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_role_change_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    role = event.respond_to?(:role) ? event.role : "unknown"
    icon = class_icon(role)

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " → ", class: "role-action"),
      icon,
      icon.present? ? "" : content_tag(:span, role, class: "role-name")
    ])

    content_tag(:span, content, class: "log-role")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_spawn_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    role = event.respond_to?(:role) ? event.role : nil
    icon = class_icon(role)

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " spawned as ", class: "spawn-action"),
      icon.present? ? icon : content_tag(:span, role, class: "role-name")
    ])

    content_tag(:span, content, class: "log-spawn")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_domination_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " is dominating ", class: "domination-action"),
      log_player_name(event.target)
    ])

    content_tag(:span, content, class: "log-domination")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_revenge_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " got revenge on ", class: "revenge-action"),
      log_player_name(event.target)
    ])

    content_tag(:span, content, class: "log-revenge")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_pickup_item_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    item = event.respond_to?(:item) ? event.item : "item"
    healing = event.respond_to?(:healing) && event.healing ? event.healing : nil

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " picked up ", class: "pickup-action"),
      content_tag(:span, item, class: "item-name"),
      healing ? content_tag(:span, " +#{healing}", class: "heal-amount") : ""
    ])

    content_tag(:span, content, class: "log-pickup")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_heal_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    healing = event.respond_to?(:healing) && event.healing ? event.healing : nil

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " healed ", class: "heal-action"),
      log_player_name(event.target),
      healing ? content_tag(:span, " +#{healing}", class: "heal-amount") : ""
    ])

    content_tag(:span, content, class: "log-heal")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_charge_deployed_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " deployed über", class: "charge-deployed-action")
    ])

    content_tag(:span, content, class: "log-charge")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_charge_ready_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " über ready!", class: "charge-ready-action")
    ])

    content_tag(:span, content, class: "log-charge-ready")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_charge_ended_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    duration = event.respond_to?(:duration) ? event.duration : nil
    duration_text = duration ? " (#{duration}s)" : ""

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " über ended#{duration_text}", class: "charge-ended-action")
    ])

    content_tag(:span, content, class: "log-charge-ended")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_lost_uber_advantage_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    time_lost = event.respond_to?(:advantage_time) ? event.advantage_time : nil
    time_text = time_lost ? " #{format_duration(time_lost)}" : ""

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " lost#{time_text} über advantage", class: "lost-uber-action")
    ])

    content_tag(:span, content, class: "log-lost-uber")
  end

  sig { params(seconds: T.nilable(T.any(Integer, Float, String))).returns(String) }
  def format_duration(seconds)
    return "" unless seconds
    seconds = seconds.to_f
    if seconds >= 60
      mins = (seconds / 60).floor
      secs = (seconds % 60).round
      "#{mins}m #{secs}s"
    else
      "#{seconds.round(1)}s"
    end
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_empty_uber_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " über depleted", class: "empty-uber-action")
    ])

    content_tag(:span, content, class: "log-empty-uber")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_first_heal_after_spawn_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    heal_time = event.respond_to?(:heal_time) ? event.heal_time : nil
    time_text = heal_time ? " (#{heal_time}s)" : ""

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " first heal#{time_text}", class: "first-heal-action")
    ])

    content_tag(:span, content, class: "log-first-heal")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_player_extinguished_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    weapon = event.respond_to?(:weapon) ? event.weapon : nil

    content = safe_join([
      log_player_name(event.player),
      weapon ? safe_join([ " ", weapon_icon(weapon), " " ]) : " ",
      content_tag(:span, "💨", class: "extinguish-icon"),
      " ",
      log_player_name(event.target)
    ])

    content_tag(:span, content, class: "log-extinguish")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_airshot_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    damage = event.respond_to?(:damage) ? event.damage : nil
    weapon = event.respond_to?(:weapon) ? event.weapon : nil

    content = safe_join([
      log_player_name(event.player),
      weapon ? safe_join([ " ", weapon_icon(weapon) ]) : "",
      content_tag(:span, "AIRSHOT", class: "airshot-badge", title: "Airshot"),
      damage ? content_tag(:span, " #{damage}", class: "damage-amount") : "",
      " ",
      log_player_name(event.target)
    ])

    content_tag(:span, content, class: "log-airshot")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_airshot_heal_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    healing = event.respond_to?(:healing) ? event.healing : nil

    content = safe_join([
      log_player_name(event.player),
      " ",
      content_tag(:span, "AIRSHOT", class: "airshot-heal-badge", title: "Airshot Heal"),
      healing ? content_tag(:span, " +#{healing}", class: "heal-amount") : "",
      " ",
      log_player_name(event.target)
    ])

    content_tag(:span, content, class: "log-airshot-heal")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_joined_team_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    team = event.respond_to?(:team) ? event.team : "unknown"
    team_class = team&.downcase || "unassigned"

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " joined ", class: "joined-action"),
      content_tag(:span, team, class: "team-name team-#{team_class}")
    ])

    content_tag(:span, content, class: "log-joined-team")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_builtobject_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    object_name = format_building_name(event.object) if event.respond_to?(:object)

    content = safe_join([
      log_player_name(event.player),
      class_icon("engineer"),
      content_tag(:span, " built #{object_name}", class: "build-action")
    ])

    content_tag(:span, content, class: "log-builtobject")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_damage_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:target)

    damage = event.respond_to?(:damage) ? event.damage : nil
    weapon = event.respond_to?(:weapon) ? event.weapon : nil
    crit = event.respond_to?(:crit) ? event.crit : nil
    headshot = event.respond_to?(:headshot) ? event.headshot : nil

    damage_class = "damage-amount"
    damage_class += " damage-crit" if crit == "crit"
    damage_class += " damage-minicrit" if crit == "mini"

    modifiers = []
    modifiers << content_tag(:span, "HS", class: "damage-headshot", title: "Headshot") if headshot

    content = safe_join([
      log_player_name(event.player),
      weapon ? safe_join([ " ", weapon_icon(weapon) ]) : "",
      damage ? content_tag(:span, " #{damage} ", class: damage_class, title: crit == "mini" ? "Mini-crit" : (crit ? "Critical" : nil)) : " ",
      safe_join(modifiers),
      content_tag(:span, "→", class: "damage-arrow"),
      " ",
      log_player_name(event.target)
    ])

    content_tag(:span, content, class: "log-damage")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_medic_death_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    uber = event.respond_to?(:ubercharge) && event.ubercharge ? " (#{event.ubercharge}%)" : ""

    content = safe_join([
      log_player_name(event.player),
      class_icon("medic"),
      content_tag(:span, " died#{uber}", class: "medic-death-action")
    ])

    content_tag(:span, content, class: "log-medic-death")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_medic_death_ex_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    uber = event.respond_to?(:ubercharge) ? event.ubercharge : nil
    is_drop = uber == 100

    if is_drop
      content = safe_join([
        log_player_name(event.player),
        class_icon("medic"),
        content_tag(:span, " DROPPED ÜBER", class: "medic-drop-action")
      ])
      content_tag(:span, content, class: "log-medic-drop")
    else
      uber_text = uber ? " (#{uber}%)" : ""
      content = safe_join([
        log_player_name(event.player),
        class_icon("medic"),
        content_tag(:span, " died#{uber_text}", class: "medic-death-action")
      ])
      content_tag(:span, content, class: "log-medic-death")
    end
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_killedobject_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player) && event.respond_to?(:objectowner)

    weapon = event.respond_to?(:weapon) ? event.weapon : nil
    object_name = format_building_name(event.object) if event.respond_to?(:object)
    owner = event.objectowner

    content = safe_join([
      log_player_name(event.player),
      weapon ? safe_join([ " ", weapon_icon(weapon), " " ]) : content_tag(:span, " destroyed ", class: "destroy-action"),
      content_tag(:span, object_name, class: "building-name"),
      " (",
      log_player_name(owner),
      ")"
    ])

    content_tag(:span, content, class: "log-killedobject")
  end

  sig { params(object: T.nilable(String)).returns(String) }
  def format_building_name(object)
    case object&.upcase
    when "OBJ_SENTRYGUN"
      "Sentry"
    when "OBJ_DISPENSER"
      "Dispenser"
    when "OBJ_TELEPORTER", "OBJ_TELEPORTER_ENTRANCE", "OBJ_TELEPORTER_EXIT"
      "Teleporter"
    when "OBJ_ATTACHMENT_SAPPER"
      "Sapper"
    else
      object&.gsub(/^OBJ_/i, "")&.titleize || "Building"
    end
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_log_line_content(formatted)
    case formatted[:type]
    when :kill
      render_kill_event(formatted)
    when :say, :team_say
      render_chat_event(formatted)
    when :connect
      render_connect_event(formatted)
    when :disconnect
      render_disconnect_event(formatted)
    when :point_capture
      render_point_capture_event(formatted)
    when :round_win, :round_start, :round_stalemate, :round_length, :current_score, :final_score, :match_end
      render_round_event(formatted)
    when :console_say
      render_console_event(formatted)
    when :suicide
      render_suicide_event(formatted)
    when :rcon
      render_rcon_event(formatted)
    when :role_change
      render_role_change_event(formatted)
    when :spawn
      render_spawn_event(formatted)
    when :domination
      render_domination_event(formatted)
    when :revenge
      render_revenge_event(formatted)
    when :pickup_item
      render_pickup_item_event(formatted)
    when :heal
      render_heal_event(formatted)
    when :charge_deployed
      render_charge_deployed_event(formatted)
    when :charge_ready
      render_charge_ready_event(formatted)
    when :charge_ended
      render_charge_ended_event(formatted)
    when :lost_uber_advantage
      render_lost_uber_advantage_event(formatted)
    when :empty_uber
      render_empty_uber_event(formatted)
    when :first_heal_after_spawn
      render_first_heal_after_spawn_event(formatted)
    when :player_extinguished
      render_player_extinguished_event(formatted)
    when :airshot
      render_airshot_event(formatted)
    when :airshot_heal
      render_airshot_heal_event(formatted)
    when :joined_team
      render_joined_team_event(formatted)
    when :builtobject
      render_builtobject_event(formatted)
    when :damage, :headshot_damage
      render_damage_event(formatted)
    when :medic_death
      render_medic_death_event(formatted)
    when :medic_death_ex
      render_medic_death_ex_event(formatted)
    when :killedobject
      render_killedobject_event(formatted)
    when :capture_block
      render_capture_block_event(formatted)
    when :shot_fired
      render_shot_fired_event(formatted)
    when :shot_hit
      render_shot_hit_event(formatted)
    else
      # Strip timestamp from unknown events since we show formatted timestamp separately
      content_without_timestamp = LogLineFormatter.strip_timestamp(formatted[:raw])
      content_tag(:span, content_without_timestamp, class: "log-content log-unknown")
    end
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_capture_block_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    cap_name = format_cap_name(event)

    content = safe_join([
      log_player_name(event.player),
      content_tag(:span, " blocked capture of ", class: "capture-block-action"),
      content_tag(:span, cap_name, class: "cap-name")
    ])

    content_tag(:span, content, class: "log-capture-block")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_shot_fired_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    weapon = event.respond_to?(:weapon) ? event.weapon : nil

    content = safe_join([
      log_player_name(event.player),
      weapon ? safe_join([ " ", weapon_icon(weapon) ]) : "",
      content_tag(:span, " fired", class: "shot-action")
    ])

    content_tag(:span, content, class: "log-shot")
  end

  sig { params(formatted: FormattedLogLine).returns(ActiveSupport::SafeBuffer) }
  def render_shot_hit_event(formatted)
    event = formatted[:event]
    return content_tag(:span, formatted[:raw], class: "log-content") unless event.respond_to?(:player)

    weapon = event.respond_to?(:weapon) ? event.weapon : nil

    content = safe_join([
      log_player_name(event.player),
      weapon ? safe_join([ " ", weapon_icon(weapon) ]) : "",
      content_tag(:span, " hit", class: "shot-hit-action")
    ])

    content_tag(:span, content, class: "log-shot")
  end
end
