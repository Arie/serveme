# typed: false
# frozen_string_literal: true

class DiscordBanAppealWorker
  include Sidekiq::Worker

  sidekiq_options queue: :discord, retry: 3

  COOLDOWN_TTL = 86_400 # 24 hours
  OPEN_APPEAL_TTL = 604_800 # 7 days

  def perform(user_id, discord_user_id, interaction_token)
    user = User.find_by(id: user_id)
    return unless user

    # Collect enrichment data from all regions
    enrichment = BanAppealEnrichmentService.new(discord_user_id).collect

    unless enrichment[:found]
      update_interaction(interaction_token, ":x: Your Discord account is not linked to any serveme.tf region. Use `/serveme link` first.")
      return
    end

    steam_uid = enrichment[:steam_uid]

    # Create private thread
    thread = create_private_thread(enrichment[:nickname])
    return unless thread

    thread_id = thread["id"]

    # Add user to thread
    add_thread_member(thread_id, discord_user_id)

    # Post user-facing message
    post_user_message(thread_id, enrichment)

    # Post admin enrichment with buttons
    admin_message = post_admin_enrichment(thread_id, enrichment, user_id)
    admin_message_id = admin_message&.dig("id")

    # Set Redis keys
    set_redis_keys(steam_uid, thread_id, admin_message_id)

    # Update interaction
    update_interaction(interaction_token, ":white_check_mark: Your ban appeal has been created. Check <##{thread_id}>.")
  rescue StandardError => e
    Rails.logger.error "[BanAppeal] Error creating appeal: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    update_interaction(interaction_token, ":x: Failed to create your ban appeal. Please try again later.")
  end

  private

  def create_private_thread(nickname)
    channel_id = Rails.application.credentials.dig(:discord, :ban_appeals_channel_id)
    truncated_name = "Appeal - #{nickname}"[0, 100]

    DiscordApiClient.create_private_thread(
      channel_id: channel_id,
      name: truncated_name
    )
  end

  def add_thread_member(thread_id, discord_user_id)
    DiscordApiClient.add_thread_member(thread_id: thread_id, user_id: discord_user_id)
  end

  def post_user_message(thread_id, enrichment)
    regions_text = enrichment[:regions]&.map(&:upcase)&.join(", ") || "Unknown"

    fields = [
      { name: "Player", value: enrichment[:nickname], inline: true },
      { name: "Ban Reason", value: enrichment[:ban_reason] || "Unknown", inline: true },
      { name: "Regions", value: regions_text, inline: true },
      { name: "Your History", value: "Member since: #{format_date(enrichment[:first_seen])}\nReservations: #{enrichment[:reservation_count]} | Games played: #{enrichment[:games_played]}", inline: false }
    ]

    fields << {
      name: "What happens next?",
      value: "1. Describe your situation below — an admin will review it\n" \
             "2. The admin may ask follow-up questions in this thread\n" \
             "3. You will receive a DM when a decision is made"
    }

    embed = {
      title: "Ban Appeal",
      color: 0xFFA500,
      fields: fields
    }

    DiscordApiClient.send_message(channel_id: thread_id, embeds: [ embed ])
  end

  def post_admin_enrichment(thread_id, enrichment, user_id)
    admin_channel_id = Rails.application.credentials.dig(:discord, :appeals_admin_channel_id)

    ban_type_text = enrichment[:ban_type]&.any? ? enrichment[:ban_type].join(", ") : "Not detected"
    ban_reason_text = enrichment[:ban_reason] || "Unknown"
    ban_reason_text += " (#{ban_type_text})" if enrichment[:ban_type]&.any?

    fields = [
      { name: "Steam Profile", value: "[#{enrichment[:steam_uid]}](https://steamcommunity.com/profiles/#{enrichment[:steam_uid]})", inline: true },
      { name: "Ban Reason", value: ban_reason_text, inline: true },
      { name: "Regions", value: enrichment[:regions]&.map(&:upcase)&.join(", ") || "Unknown", inline: true },
      { name: "Account Age", value: "First seen: #{format_date(enrichment[:first_seen])}\nLast seen: #{format_date(enrichment[:last_seen])}\nReservations: #{enrichment[:reservation_count]} | Games played: #{enrichment[:games_played]}", inline: false }
    ]

    # STAC detections
    if enrichment[:stac_detections]&.any?
      stac_lines = enrichment[:stac_detections].map { |d| "#{d[:detection_type]}: #{d[:count]}" }
      fields << { name: "STAC Detections", value: stac_lines.join("\n"), inline: false }
    end

    # IP info
    if enrichment[:ip_lookups]&.any?
      ip_lines = enrichment[:ip_lookups].first(5).map do |ip|
        "#{ip[:ip]} (fraud: #{ip[:fraud_score]}, #{ip[:isp]}, #{ip[:country_code]}#{ip[:is_proxy] ? ', PROXY' : ''})"
      end
      fields << { name: "IPs", value: ip_lines.join("\n"), inline: false }
    end

    # Alts
    if enrichment[:alts]&.any?
      banned_count = enrichment[:alts].count { |a| a[:banned] }
      alt_header = "Known Alts (#{enrichment[:alts].size})"
      alt_header += " — #{banned_count} banned" if banned_count > 0

      alt_lines = enrichment[:alts].first(10).map do |alt|
        status = alt[:banned] ? " [BANNED: #{alt[:ban_reason]}]" : ""
        base_url = region_base_url(alt[:region])
        "[#{alt[:name] || alt[:steam_uid]}](#{base_url}/league-request?steam_uid=#{alt[:steam_uid]}&cross_reference=1&include_vpn_results=1) (#{alt[:reservation_count]} reservations)#{status}"
      end
      fields << { name: alt_header, value: alt_lines.join("\n"), inline: false }
    end

    fields << { name: "Thread", value: "<##{thread_id}>", inline: true }

    steam_uid = enrichment[:steam_uid]
    regions = enrichment[:regions] || [ "eu" ]
    serveme_links = regions.map do |r|
      base = region_base_url(r)
      "[#{r.upcase}](#{base}/league-request?steam_uid=#{steam_uid}&cross_reference=1&include_vpn_results=1)"
    end
    investigate_links = [
      "serveme: #{serveme_links.join(' ')}",
      "[Steam History](https://steamhistory.net/id/#{steam_uid})",
      "[logs.tf](https://logs.tf/profile/#{steam_uid})",
      "[RGL](https://rgl.gg/Public/PlayerProfile?p=#{steam_uid})",
      "[ETF2L](https://etf2l.org/search/#{steam_uid}/)",
      "[UGC](https://www.ugcleague.com/players_page.cfm?player_id=#{steam_uid})"
    ]
    fields << { name: "Investigate", value: investigate_links.join(" | "), inline: false }

    embed = {
      title: "Ban Appeal - #{enrichment[:nickname]}",
      color: 0xFF0000,
      fields: fields
    }

    components = [
      {
        type: 1,
        components: [
          { type: 2, style: 3, label: "Approve", custom_id: "appeal_approve:#{user_id}:#{thread_id}" },
          { type: 2, style: 4, label: "Deny", custom_id: "appeal_deny:#{user_id}:#{thread_id}" }
        ]
      }
    ]

    DiscordApiClient.send_message(channel_id: admin_channel_id, embeds: [ embed ], components: components)
  end

  def set_redis_keys(steam_uid, thread_id, admin_message_id)
    Sidekiq.redis do |redis|
      redis.set("ban_appeal_open:#{steam_uid}", "#{thread_id}:#{admin_message_id}", ex: OPEN_APPEAL_TTL)
      redis.set("ban_appeal_cooldown:#{steam_uid}", "1", ex: COOLDOWN_TTL)
    end
  end

  def update_interaction(interaction_token, content)
    DiscordApiClient.update_interaction_response(interaction_token: interaction_token, content: content)
  rescue StandardError => e
    Rails.logger.warn "[BanAppeal] Failed to update interaction: #{e.message}"
  end

  def region_base_url(region)
    case region
    when "na" then "https://na.serveme.tf"
    when "sea" then "https://sea.serveme.tf"
    when "au" then "https://au.serveme.tf"
    else "https://serveme.tf"
    end
  end

  def format_date(iso_string)
    return "N/A" unless iso_string
    Time.parse(iso_string).strftime("%-d %b %Y")
  end
end
