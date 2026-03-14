# typed: false
# frozen_string_literal: true

class DiscordBanAppealDecisionWorker
  include Sidekiq::Worker

  sidekiq_options queue: :discord, retry: 3

  def perform(user_id, thread_id, admin_message_id, decision, admin_discord_uid, interaction_token)
    user = User.find_by(id: user_id)
    return unless user

    admin = User.find_by(discord_uid: admin_discord_uid)
    admin_name = admin&.nickname || admin_discord_uid

    case decision
    when "approved"
      handle_approve(user, thread_id, admin_message_id, admin_name, interaction_token)
    when "denied"
      handle_deny(user, thread_id, admin_message_id, admin_name, interaction_token)
    end
  end

  private

  def handle_approve(user, thread_id, admin_message_id, admin_name, interaction_token)
    # Post in thread
    DiscordApiClient.send_message(
      channel_id: thread_id,
      content: ":white_check_mark: Your appeal has been approved by an admin. Your ban will be removed soon."
    )

    # Archive and lock thread
    DiscordApiClient.archive_thread(thread_id: thread_id)

    # DM user
    send_dm(user.discord_uid, "Your ban appeal on serveme.tf has been approved. You should be able to use the service again soon.")

    # Update admin message
    update_admin_message(admin_message_id, admin_name, "approved")

    # Clear open appeal
    clear_open_appeal(user.uid)

    # Update interaction
    update_interaction(interaction_token, ":white_check_mark: Appeal approved. Remember to edit the ban CSV.")
  end

  def handle_deny(user, thread_id, admin_message_id, admin_name, interaction_token)
    # Post in thread
    DiscordApiClient.send_message(
      channel_id: thread_id,
      content: ":x: Your appeal has been denied."
    )

    # Archive and lock thread
    DiscordApiClient.archive_thread(thread_id: thread_id)

    # DM user
    send_dm(user.discord_uid, "Your ban appeal on serveme.tf has been denied.")

    # Update admin message
    update_admin_message(admin_message_id, admin_name, "denied")

    # Clear open appeal (cooldown remains)
    clear_open_appeal(user.uid)

    # Update interaction
    update_interaction(interaction_token, ":x: Appeal denied.")
  end

  def send_dm(discord_uid, message)
    dm_channel = DiscordApiClient.create_dm_channel(user_id: discord_uid)
    return unless dm_channel

    DiscordApiClient.send_message(channel_id: dm_channel["id"], content: message)
  rescue StandardError => e
    Rails.logger.warn "[BanAppeal] Could not DM user #{discord_uid}: #{e.message}"
  end

  def update_admin_message(admin_message_id, admin_name, decision)
    admin_channel_id = Rails.application.credentials.dig(:discord, :appeals_admin_channel_id)
    return unless admin_channel_id && admin_message_id

    # Fetch the existing message to preserve enrichment data
    existing = DiscordApiClient.get_message(channel_id: admin_channel_id, message_id: admin_message_id)
    return unless existing

    color = decision == "approved" ? 0x00FF00 : 0xFF0000
    label = decision == "approved" ? "APPROVED" : "DENIED"

    # Update the original embed's color and title, keeping all fields
    embed = (existing["embeds"]&.first || {}).deep_symbolize_keys
    embed[:color] = color
    embed[:title] = "#{embed[:title]} — #{label} by #{admin_name}"

    DiscordApiClient.update_message(
      channel_id: admin_channel_id,
      message_id: admin_message_id,
      embed: embed,
      components: []
    )
  rescue StandardError => e
    Rails.logger.warn "[BanAppeal] Failed to update admin message: #{e.message}"
  end

  def clear_open_appeal(steam_uid)
    Sidekiq.redis do |redis|
      redis.del("ban_appeal_open:#{steam_uid}")
    end
  end

  def update_interaction(interaction_token, content)
    DiscordApiClient.update_interaction_response(interaction_token: interaction_token, content: content)
  rescue StandardError => e
    Rails.logger.warn "[BanAppeal] Failed to update interaction: #{e.message}"
  end
end
