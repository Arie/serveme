# typed: false
# frozen_string_literal: true

require "spec_helper"

describe LogLineViewHelper do
  let(:ts) { "L 02/07/2013 - 21:37:20:" }
  let(:red) { '"Attacker<14><[U:1:231702]><Red>"' }
  let(:blue) { '"Victim<15><[U:1:231704]><Blue>"' }

  define_method(:formatted) do |line, admin: false|
    LogLineFormatter.new(line).format(skip_sanitization: admin)
  end

  define_method(:render) do |line, admin: false|
    helper.render_log_line_content(formatted(line, admin: admin))
  end

  define_method(:fragment) do |html|
    Nokogiri::HTML::DocumentFragment.parse(html.to_s)
  end

  define_method(:killicon_classes) do |html|
    fragment(html).css(".killicon").map { |n| n["class"] }
  end

  describe "#class_icon" do
    it "returns an empty string for blank class names" do
      expect(helper.class_icon(nil)).to eq("")
      expect(helper.class_icon("")).to eq("")
    end

    it "returns an empty string for unknown classes" do
      expect(helper.class_icon("civilian")).to eq("")
    end

    it "renders an accessible icon span for known classes, case-insensitively" do
      node = fragment(helper.class_icon("Medic")).at_css("span")

      expect(node["class"]).to eq("class-icon class-icon-medic")
      expect(node["role"]).to eq("img")
      expect(node["title"]).to eq("Medic")
      expect(node["aria-label"]).to eq("Medic")
    end
  end

  describe "#weapon_icon" do
    it "uses the lowercased weapon as killicon class" do
      node = fragment(helper.weapon_icon("Scattergun")).at_css("span")

      expect(node["class"]).to eq("killicon killicon-scattergun")
      expect(node["title"]).to eq("Scattergun")
    end

    it "falls back to default when weapon is nil" do
      node = fragment(helper.weapon_icon(nil)).at_css("span")

      expect(node["class"]).to eq("killicon killicon-default")
      expect(node["title"]).to eq("unknown")
    end
  end

  describe "#log_player_name" do
    let(:player) { TF2LineParser::Player.new("Arie <b>", "1", "[U:1:231702]", "Red") }

    it "renders Unknown for a missing player" do
      node = fragment(helper.log_player_name(nil)).at_css("span")

      expect(node.text).to eq("Unknown")
      expect(node["class"]).to eq("player-name team-unassigned")
    end

    it "links to the steam profile and escapes the name" do
      html = helper.log_player_name(player)
      node = fragment(html).at_css("a")

      expect(html).to include("Arie &lt;b&gt;")
      expect(node["href"]).to eq("https://steamcommunity.com/profiles/76561197960497430")
      expect(node["class"]).to eq("player-name team-red")
      expect(node["title"]).to eq("[U:1:231702]")
    end

    it "links to the league request page in league request mode" do
      node = fragment(helper.log_player_name(player, league_request_link: true)).at_css("a")

      expect(node["href"]).to include("steam_uid=76561197960497430")
      expect(node["href"]).to include("cross_reference=true")
      expect(node["title"]).to eq("[U:1:231702] (76561197960497430)")
    end

    it "renders a plain span when linking is disabled" do
      html = helper.log_player_name(player, link: false)

      expect(fragment(html).at_css("a")).to be_nil
      expect(fragment(html).at_css("span.player-name.team-red").text).to eq("Arie <b>")
    end

    it "renders a plain span for players without a community id" do
      bot = TF2LineParser::Player.new("SourceTV", "2", "BOT", nil)
      node = fragment(helper.log_player_name(bot)).at_css("span")

      expect(node["class"]).to eq("player-name team-unassigned")
      expect(node.text).to eq("SourceTV")
    end
  end

  describe "#log_timestamp" do
    it "renders an empty span without time" do
      expect(helper.log_timestamp(nil)).to eq('<span class="log-timestamp"></span>')
    end

    it "renders the time with a full date title" do
      node = fragment(helper.log_timestamp(Time.new(2026, 9, 27, 13, 5, 9))).at_css("span")

      expect(node.text).to eq("13:05:09")
      expect(node["title"]).to eq("2026-09-27 13:05:09")
    end
  end

  describe "kill events" do
    define_method(:kill) do |weapon, customkill = nil|
      suffix = customkill ? %( (customkill "#{customkill}")) : ""
      render(%(#{ts} #{red} killed #{blue} with "#{weapon}"#{suffix} (attacker_position "1 2 3")))
    end

    it "renders attacker, weapon icon and victim" do
      html = kill("scattergun")
      doc = fragment(html)

      expect(doc.at_css("span.log-kill")).to be_present
      expect(doc.css(".player-name").map(&:text)).to eq(%w[Attacker Victim])
      expect(killicon_classes(html)).to eq([ "killicon killicon-scattergun" ])
      expect(doc.at_css(".kill-modifier")).to be_nil
    end

    it "maps projectile aliases to weapon icons" do
      expect(killicon_classes(kill("tf_projectile_arrow"))).to eq([ "killicon killicon-huntsman" ])
      expect(killicon_classes(kill("prop_physics"))).to eq([ "killicon killicon-skull" ])
    end

    it "uses the generic backstab icon for regular knives" do
      expect(killicon_classes(kill("knife", "backstab"))).to eq([ "killicon killicon-backstab" ])
    end

    it "uses weapon-specific backstab icons" do
      expect(killicon_classes(kill("kunai", "backstab"))).to eq([ "killicon killicon-kunai_backstab" ])
      expect(killicon_classes(kill("conniver_kunai", "backstab"))).to eq([ "killicon killicon-kunai_backstab" ])
    end

    it "uses weapon-specific headshot icons without a HS badge" do
      html = kill("ambassador", "headshot")

      expect(killicon_classes(html)).to eq([ "killicon killicon-ambassador_headshot" ])
      expect(fragment(html).at_css(".kill-modifier")).to be_nil
    end

    it "uses the aliased huntsman headshot icon" do
      expect(killicon_classes(kill("tf_projectile_arrow", "headshot"))).to eq([ "killicon killicon-huntsman_headshot" ])
    end

    it "uses the generic headshot icon for sniper rifles" do
      html = kill("sniperrifle", "headshot")

      expect(killicon_classes(html)).to eq([ "killicon killicon-headshot" ])
      expect(fragment(html).at_css(".kill-modifier")).to be_nil
    end

    it "adds a HS badge for headshots with other weapons" do
      html = kill("sydney_sleeper", "headshot")
      badge = fragment(html).at_css(".kill-modifier.headshot")

      expect(killicon_classes(html)).to eq([ "killicon killicon-sydney_sleeper" ])
      expect(badge.text).to eq("HS")
      expect(badge["title"]).to eq("Headshot")
    end

    {
      "taunt_heavy" => [ "taunt", "Taunt Kill" ],
      "bleed" => [ "bleed", "Bleed" ],
      "burning" => [ "burning", "Afterburn" ],
      "reflected" => [ "reflected", "Reflected" ],
      "gib" => [ "gib", "Gibbed" ]
    }.each do |customkill, (css, title)|
      it "adds a #{css} modifier for #{customkill} kills" do
        badge = fragment(kill("fists", customkill)).at_css(".kill-modifier.#{css}")

        expect(badge["title"]).to eq(title)
      end
    end

    it "adds no modifier for unrecognised customkills" do
      expect(fragment(kill("fists", "fish_kill")).at_css(".kill-modifier")).to be_nil
    end

    it "falls back to the raw line without an event" do
      html = helper.render_kill_event({ event: nil, raw: "raw kill" })

      expect(html).to eq('<span class="log-content">raw kill</span>')
    end
  end

  describe "chat events" do
    it "renders say lines" do
      doc = fragment(render(%(#{ts} #{red} say "gg")))

      expect(doc.at_css("span.log-chat .player-name").text).to eq("Attacker")
      expect(doc.at_css(".chat-message").text).to eq("gg")
    end

    it "prefixes team chat" do
      doc = fragment(render(%(#{ts} #{red} say_team "push now")))

      expect(doc.at_css(".chat-message").text).to eq("(TEAM) push now")
    end

    it "escapes chat messages" do
      html = render(%(#{ts} #{red} say "<script>alert(1)</script>"))

      expect(html).not_to include("<script>")
      expect(html).to include("&lt;script&gt;")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_chat_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "connect events" do
    let(:line) { %(#{ts} #{red} connected, address "1.2.3.4:27005") }

    it "shows the sanitized address for non-admins" do
      html = render(line)
      doc = fragment(html)

      expect(doc.at_css("span.log-connect").text).to eq("Attacker connected from 0.0.0.0:27005")
      expect(doc.at_css(".ip-address-link")).to be_nil
      expect(html).not_to include("1.2.3.4")
    end

    it "links the IP to the league request page for admins" do
      doc = fragment(render(line, admin: true))
      ip_link = doc.at_css("a.ip-address-link")
      player_link = doc.at_css("a.player-name")

      expect(ip_link.text).to eq("1.2.3.4:27005")
      expect(ip_link["href"]).to include("ip=1.2.3.4")
      expect(player_link["href"]).to include("steam_uid=76561197960497430")
    end

    it "does not link the placeholder IP for admins" do
      doc = fragment(render(%(#{ts} #{red} connected, address "0.0.0.0:27005"), admin: true))

      expect(doc.at_css(".ip-address-link")).to be_nil
      expect(doc.text).to include("from 0.0.0.0:27005")
    end

    it "omits the address when empty" do
      doc = fragment(render(%(#{ts} "SourceTV<2><BOT><>" connected, address "")))

      expect(doc.at_css("span.log-connect").text).to eq("SourceTV connected")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_connect_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "disconnect events" do
    it "renders the disconnect reason" do
      doc = fragment(render(%(#{ts} #{red} disconnected (reason "Disconnect by user."))))

      expect(doc.at_css("span.log-disconnect .disconnect-action").text).to eq(" disconnected (Disconnect by user.)")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_disconnect_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "point capture events" do
    it "renders the capturing team and cap name" do
      line = %(#{ts} Team "Blue" triggered "pointcaptured" (cp "2") (cpname "#Badlands_cap_cp3") (numcappers "1") (player1 #{blue}) (position1 "1 2 3") )
      doc = fragment(render(line))

      expect(doc.at_css("span.log-capture .player-name.team-blue").text).to eq("Blue")
      expect(doc.at_css(".capture-action").text).to eq(" captured #Badlands_cap_cp3")
    end

    it "renders the capturing player when present" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("Capper", "1", "[U:1:231702]", "Red")
      event.cap_number = "3"
      doc = fragment(helper.render_point_capture_event({ event: event, raw: "raw" }))

      expect(doc.at_css(".player-name").text).to eq("Capper")
      expect(doc.at_css(".capture-action").text).to eq(" captured point 3")
    end

    it "falls back to the raw line without player or team" do
      event = TF2LineParser::Events::Event.new

      expect(helper.render_point_capture_event({ event: event, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "#format_cap_name" do
    let(:event) { TF2LineParser::Events::Event.new }

    it "prefers the cap name" do
      event.cap_name = "Mid"
      event.cap_number = "3"

      expect(helper.format_cap_name(event)).to eq("Mid")
    end

    it "falls back to the cap number and then a generic label" do
      expect(helper.format_cap_name(event)).to eq("control point")

      event.cap_number = "3"
      expect(helper.format_cap_name(event)).to eq("point 3")
    end
  end

  describe "capture block events" do
    it "renders the blocker and the cap name" do
      doc = fragment(render(%(#{ts} #{red} triggered "captureblocked" (cp "3") (cpname "Granary_cap_red_cp2") (position "1 2 3"))))

      expect(doc.at_css("span.log-capture-block .player-name").text).to eq("Attacker")
      expect(doc.at_css(".cap-name").text).to eq("Granary_cap_red_cp2")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_capture_block_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "round events" do
    define_method(:round_text) do |line|
      fragment(render(line)).at_css("span.log-round").text
    end

    it "renders round lifecycle lines" do
      expect(round_text(%(#{ts} World triggered "Round_Win" (winner "Blue")))).to eq("Round won by Blue")
      expect(round_text(%(#{ts} World triggered "Round_Start"))).to eq("Round started")
      expect(round_text(%(#{ts} World triggered "Round_Stalemate"))).to eq("Round ended in stalemate")
      expect(round_text(%(#{ts} World triggered "Game_Over" reason "Reached Win Difference Limit"))).to eq("Match ended")
    end

    it "renders scores" do
      expect(round_text(%(#{ts} Team "Red" current score "2" with "6" players))).to eq("Red: 2")
      expect(round_text(%(#{ts} Team "Blue" final score "5" with "6" players))).to eq("Final - Blue: 5")
    end

    it "renders round length as minutes and zero-padded seconds" do
      expect(round_text(%(#{ts} World triggered "Round_Length" (seconds "96.54")))).to eq("Round length: 1:37")
      expect(round_text(%(#{ts} World triggered "Round_Length" (seconds "5.2")))).to eq("Round length: 0:05")
    end

    it "falls back to the raw line when the event lacks attributes" do
      %i[current_score final_score round_length].each do |type|
        html = helper.render_round_event({ type: type, event: nil, raw: "raw #{type}" })

        expect(html).to eq(%(<span class="log-round">raw #{type}</span>))
      end
    end

    it "falls back to the raw line for unhandled types" do
      expect(helper.render_round_event({ type: :other, event: nil, raw: "raw" })).to eq('<span class="log-round">raw</span>')
    end
  end

  describe "console and rcon events" do
    it "renders console say" do
      doc = fragment(render(%(#{ts} "Console<0><Console><Console>" say "Config loaded")))

      expect(doc.at_css("span.log-console").text).to eq("Console: Config loaded")
    end

    it "falls back to the raw line for console without message" do
      doc = fragment(helper.render_console_event({ message: nil, raw: "raw console" }))

      expect(doc.at_css(".console-message").text).to eq("raw console")
    end

    it "renders rcon commands with the sanitized source address" do
      doc = fragment(render(%(#{ts} rcon from "1.2.3.4:41380": command "status")))

      expect(doc.at_css("span.log-rcon .rcon-prefix").text).to eq("RCON: ")
      expect(doc.at_css(".rcon-message").text).to eq(%("0.0.0.0:41380": command "status"))
    end

    it "falls back to the raw line for rcon without message" do
      doc = fragment(helper.render_rcon_event({ message: nil, raw: "raw rcon" }))

      expect(doc.at_css(".rcon-message").text).to eq("raw rcon")
    end
  end

  describe "suicide events" do
    it "renders the suicide" do
      doc = fragment(render(%(#{ts} #{red} committed suicide with "world" (attacker_position "1 2 3"))))

      expect(doc.at_css("span.log-suicide .player-name").text).to eq("Attacker")
      expect(doc.at_css(".suicide-action").text).to eq(" suicided")
    end

    it "shows what the player suicided with" do
      html = render(%(#{ts} #{red} committed suicide with "tf_projectile_pipe" (attacker_position "1 2 3")))

      expect(fragment(html).text).to include("suicided with")
      expect(killicon_classes(html)).to eq([ "killicon killicon-tf_projectile_pipe" ])
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_suicide_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "role change and spawn events" do
    it "renders a class icon for known roles" do
      doc = fragment(render(%(#{ts} #{red} changed role to "demoman")))

      expect(doc.at_css("span.log-role .class-icon-demoman")).to be_present
      expect(doc.at_css(".role-name")).to be_nil
    end

    it "renders the role name for unknown roles" do
      doc = fragment(render(%(#{ts} #{red} changed role to "civilian")))

      expect(doc.at_css(".role-name").text).to eq("civilian")
    end

    it "renders spawns with a class icon" do
      doc = fragment(render(%(#{ts} #{blue} spawned as "Medic")))

      expect(doc.at_css("span.log-spawn .spawn-action").text).to eq(" spawned as ")
      expect(doc.at_css(".class-icon-medic")).to be_present
    end

    it "renders spawns with unknown roles as text" do
      doc = fragment(render(%(#{ts} #{blue} spawned as "Civilian")))

      expect(doc.at_css(".role-name").text).to eq("Civilian")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_role_change_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      expect(helper.render_spawn_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "domination and revenge events" do
    it "renders dominations" do
      doc = fragment(render(%(#{ts} #{red} triggered "domination" against #{blue})))

      expect(doc.at_css("span.log-domination").text).to eq("Attacker is dominating Victim")
    end

    it "renders revenge" do
      doc = fragment(render(%(#{ts} #{blue} triggered "revenge" against #{red})))

      expect(doc.at_css("span.log-revenge").text).to eq("Victim got revenge on Attacker")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_domination_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      expect(helper.render_revenge_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "pickup and heal events" do
    it "renders item pickups" do
      doc = fragment(render(%(#{ts} #{red} picked up item "medkit_medium")))

      expect(doc.at_css("span.log-pickup .item-name").text).to eq("medkit_medium")
      expect(doc.at_css(".heal-amount")).to be_nil
    end

    it "renders the healing amount of pickups" do
      doc = fragment(render(%(#{ts} #{red} picked up item "medkit_small" (healing "40"))))

      expect(doc.at_css(".heal-amount").text).to eq(" +40")
    end

    it "renders heals" do
      doc = fragment(render(%(#{ts} #{blue} triggered "healed" against #{red} (healing "82"))))

      expect(doc.at_css("span.log-heal").text).to eq("Victim healed Attacker +82")
    end

    it "renders heals without an amount" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("Med", "1", "[U:1:231702]", "Blue")
      event.target = TF2LineParser::Player.new("Pat", "2", "[U:1:231704]", "Blue")
      doc = fragment(helper.render_heal_event({ event: event, raw: "raw" }))

      expect(doc.at_css("span.log-heal").text).to eq("Med healed Pat")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_pickup_item_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      expect(helper.render_heal_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "medic events" do
    it "renders uber deployed" do
      doc = fragment(render(%(#{ts} #{blue} triggered "chargedeployed")))

      expect(doc.at_css("span.log-charge .class-icon-medic")).to be_present
      expect(doc.at_css(".charge-deployed-action").text).to eq(" deployed über")
    end

    it "renders uber ready" do
      doc = fragment(render(%(#{ts} #{blue} triggered "chargeready")))

      expect(doc.at_css("span.log-charge-ready .charge-ready-action").text).to eq(" über ready!")
    end

    it "renders uber ended with duration" do
      doc = fragment(render(%(#{ts} #{blue} triggered "chargeended" (duration "6.3"))))

      expect(doc.at_css("span.log-charge-ended .charge-ended-action").text).to eq(" über ended (6.3s)")
    end

    it "renders uber ended without duration" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("Med", "1", "[U:1:231702]", "Blue")
      doc = fragment(helper.render_charge_ended_event({ event: event, raw: "raw" }))

      expect(doc.at_css(".charge-ended-action").text).to eq(" über ended")
    end

    it "renders lost uber advantage with a formatted duration" do
      doc = fragment(render(%(#{ts} #{red} triggered "lost_uber_advantage" (time "75"))))

      expect(doc.at_css("span.log-lost-uber .lost-uber-action").text).to eq(" lost 1m 15s über advantage")
    end

    it "renders empty uber" do
      doc = fragment(render(%(#{ts} #{red} triggered "empty_uber")))

      expect(doc.at_css("span.log-empty-uber .empty-uber-action").text).to eq(" über depleted")
    end

    it "renders first heal after spawn" do
      doc = fragment(render(%(#{ts} #{red} triggered "first_heal_after_spawn" (time "54.7"))))

      expect(doc.at_css("span.log-first-heal .first-heal-action").text).to eq(" first heal (54.7s)")
    end

    it "renders a dropped uber when the medic died at 100%" do
      doc = fragment(render(%(#{ts} #{red} triggered "medic_death_ex" (uberpct "100"))))

      expect(doc.at_css("span.log-medic-drop .medic-drop-action").text).to eq(" DROPPED ÜBER")
    end

    it "renders a regular medic death with uber percentage" do
      doc = fragment(render(%(#{ts} #{red} triggered "medic_death_ex" (uberpct "10"))))

      expect(doc.at_css("span.log-medic-death .medic-death-action").text).to eq(" died (10%)")
    end

    it "falls back to the raw line without an event" do
      %i[
        render_charge_deployed_event render_charge_ready_event render_charge_ended_event
        render_lost_uber_advantage_event render_empty_uber_event render_first_heal_after_spawn_event
        render_medic_death_ex_event
      ].each do |method|
        expect(helper.public_send(method, { event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      end
    end
  end

  describe "#format_duration" do
    it "formats durations" do
      expect(helper.format_duration(nil)).to eq("")
      expect(helper.format_duration("12.34")).to eq("12.3s")
      expect(helper.format_duration(60)).to eq("1m 0s")
      expect(helper.format_duration(125.6)).to eq("2m 6s")
    end
  end

  describe "extinguish and airshot events" do
    it "renders extinguishes with the weapon icon" do
      html = render(%(#{ts} #{blue} triggered "player_extinguished" against #{red} with "tf_weapon_medigun" (attacker_position "1 2 3") (victim_position "4 5 6")))
      doc = fragment(html)

      expect(doc.at_css("span.log-extinguish .extinguish-icon")).to be_present
      expect(doc.css(".player-name").map(&:text)).to eq(%w[Victim Attacker])
      expect(killicon_classes(html)).to eq([ "killicon killicon-tf_weapon_medigun" ])
    end

    it "renders extinguishes without a weapon" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("Pyro", "1", "[U:1:231702]", "Red")
      event.target = TF2LineParser::Player.new("Mate", "2", "[U:1:231704]", "Red")
      html = helper.render_player_extinguished_event({ event: event, raw: "raw" })

      expect(fragment(html).at_css(".killicon")).to be_nil
      expect(fragment(html).text).to eq("Pyro 💨 Mate")
    end

    it "renders airshots with weapon and damage" do
      html = render(%(#{ts} #{red} triggered "damage" against #{blue} (damage "47") (weapon "tf_projectile_rocket") (airshot "1")))
      doc = fragment(html)

      expect(doc.at_css("span.log-airshot .airshot-badge").text).to eq("AIRSHOT")
      expect(doc.at_css(".damage-amount").text).to eq(" 47")
      expect(killicon_classes(html)).to eq([ "killicon killicon-tf_projectile_rocket" ])
    end

    it "renders airshots without weapon or damage" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("Solly", "1", "[U:1:231702]", "Red")
      event.target = TF2LineParser::Player.new("Scout", "2", "[U:1:231704]", "Blue")
      doc = fragment(helper.render_airshot_event({ event: event, raw: "raw" }))

      expect(doc.at_css(".killicon")).to be_nil
      expect(doc.at_css(".damage-amount")).to be_nil
      expect(doc.text).to eq("SollyAIRSHOT Scout")
    end

    it "renders airshot heals" do
      doc = fragment(render(%(#{ts} #{blue} triggered "healed" against #{red} (healing "82") (airshot "1") (height "261"))))

      expect(doc.at_css("span.log-airshot-heal .airshot-heal-badge").text).to eq("AIRSHOT")
      expect(doc.at_css(".heal-amount").text).to eq(" +82")
    end

    it "falls back to the raw line without an event" do
      %i[render_player_extinguished_event render_airshot_event render_airshot_heal_event].each do |method|
        expect(helper.public_send(method, { event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      end
    end
  end

  describe "joined team events" do
    it "renders the joined team with team styling" do
      doc = fragment(render(%(#{ts} "New<19><[U:1:231702]><Unassigned>" joined team "Blue")))
      team = doc.at_css("span.log-joined-team .team-name")

      expect(team.text).to eq("Blue")
      expect(team["class"]).to eq("team-name team-blue")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_joined_team_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "building events" do
    it "renders built objects with friendly names" do
      doc = fragment(render(%(#{ts} #{red} triggered "player_builtobject" (object "OBJ_SENTRYGUN") (position "1 2 3"))))

      expect(doc.at_css("span.log-builtobject .class-icon-engineer")).to be_present
      expect(doc.at_css(".build-action").text).to eq(" built Sentry")
    end

    it "renders destroyed buildings with weapon and owner" do
      line = %(#{ts} #{red} triggered "killedobject" (object "OBJ_DISPENSER") (weapon "tf_projectile_rocket") (objectowner #{blue}) (attacker_position "1 2 3"))
      html = render(line)
      doc = fragment(html)

      expect(doc.at_css("span.log-killedobject .building-name").text).to eq("Dispenser")
      expect(doc.css(".player-name").map(&:text)).to eq(%w[Attacker Victim])
      expect(killicon_classes(html)).to eq([ "killicon killicon-tf_projectile_rocket" ])
    end

    it "renders destroyed buildings without a weapon" do
      event = TF2LineParser::Events::KilledObject.allocate
      event.instance_variable_set(:@player, TF2LineParser::Player.new("Spy", "1", "[U:1:231702]", "Red"))
      event.instance_variable_set(:@objectowner, TF2LineParser::Player.new("Engi", "2", "[U:1:231704]", "Blue"))
      event.instance_variable_set(:@object, "OBJ_ATTACHMENT_SAPPER")
      doc = fragment(helper.render_killedobject_event({ event: event, raw: "raw" }))

      expect(doc.at_css(".destroy-action").text).to eq(" destroyed ")
      expect(doc.text).to eq("Spy destroyed Sapper (Engi)")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_builtobject_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      expect(helper.render_killedobject_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "#format_building_name" do
    it "maps known buildings and titleizes others" do
      expect(helper.format_building_name("OBJ_SENTRYGUN")).to eq("Sentry")
      expect(helper.format_building_name("obj_dispenser")).to eq("Dispenser")
      expect(helper.format_building_name("OBJ_TELEPORTER_EXIT")).to eq("Teleporter")
      expect(helper.format_building_name("OBJ_ATTACHMENT_SAPPER")).to eq("Sapper")
      expect(helper.format_building_name("OBJ_MINI_THING")).to eq("Mini Thing")
      expect(helper.format_building_name(nil)).to eq("Building")
    end
  end

  describe "damage events" do
    it "renders regular damage" do
      html = render(%(#{ts} #{red} triggered "damage" against #{blue} (damage "50") (weapon "scattergun")))
      doc = fragment(html)
      amount = doc.at_css(".damage-amount")

      expect(doc.at_css("span.log-damage .damage-arrow")).to be_present
      expect(amount.text).to eq(" 50 ")
      expect(amount["class"]).to eq("damage-amount")
      expect(amount["title"]).to be_nil
      expect(killicon_classes(html)).to eq([ "killicon killicon-scattergun" ])
    end

    it "marks crits" do
      amount = fragment(render(%(#{ts} #{red} triggered "damage" against #{blue} (damage "150") (weapon "tf_projectile_rocket") (crit "crit")))).at_css(".damage-amount")

      expect(amount["class"]).to eq("damage-amount damage-crit")
      expect(amount["title"]).to eq("Critical")
    end

    it "marks mini-crits" do
      amount = fragment(render(%(#{ts} #{red} triggered "damage" against #{blue} (damage "60") (weapon "shotgun_soldier") (crit "mini")))).at_css(".damage-amount")

      expect(amount["class"]).to eq("damage-amount damage-minicrit")
      expect(amount["title"]).to eq("Mini-crit")
    end

    it "adds a headshot badge for headshot damage" do
      doc = fragment(render(%(#{ts} #{red} triggered "damage" against #{blue} (damage "50") (weapon "sniperrifle") (healing "4") (headshot "1"))))

      expect(doc.at_css(".damage-headshot").text).to eq("HS")
    end

    it "renders damage without weapon or amount" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("A", "1", "[U:1:231702]", "Red")
      event.target = TF2LineParser::Player.new("B", "2", "[U:1:231704]", "Blue")
      doc = fragment(helper.render_damage_event({ event: event, raw: "raw" }))

      expect(doc.at_css(".killicon")).to be_nil
      expect(doc.at_css(".damage-amount")).to be_nil
      expect(doc.text).to eq("A → B")
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_damage_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "shot events" do
    it "renders shots fired" do
      html = render(%(#{ts} #{red} triggered "shot_fired" (weapon "tf_projectile_rocket")))

      expect(fragment(html).at_css("span.log-shot .shot-action").text).to eq(" fired")
      expect(killicon_classes(html)).to eq([ "killicon killicon-tf_projectile_rocket" ])
    end

    it "renders shots hit" do
      html = render(%(#{ts} #{red} triggered "shot_hit" (weapon "scattergun")))

      expect(fragment(html).at_css("span.log-shot .shot-hit-action").text).to eq(" hit")
      expect(killicon_classes(html)).to eq([ "killicon killicon-scattergun" ])
    end

    it "omits the weapon icon when there is no weapon" do
      event = TF2LineParser::Events::Event.new
      event.player = TF2LineParser::Player.new("A", "1", "[U:1:231702]", "Red")

      expect(fragment(helper.render_shot_fired_event({ event: event, raw: "raw" })).at_css(".killicon")).to be_nil
      expect(fragment(helper.render_shot_hit_event({ event: event, raw: "raw" })).at_css(".killicon")).to be_nil
    end

    it "falls back to the raw line without an event" do
      expect(helper.render_shot_fired_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
      expect(helper.render_shot_hit_event({ event: nil, raw: "raw" })).to eq('<span class="log-content">raw</span>')
    end
  end

  describe "unknown events" do
    it "strips the timestamp and renders the raw line" do
      html = render(%(#{ts} Some unrecognised server output))

      expect(html).to eq('<span class="log-content log-unknown">Some unrecognised server output</span>')
    end
  end
end
