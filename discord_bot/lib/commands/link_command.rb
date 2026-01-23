# typed: false
# frozen_string_literal: true

module ServemeBot
  module Commands
    class LinkCommand < BaseCommand
      def execute(unlink: false)
        log_command(unlink ? "unlink" : "link")
        if unlink
          unlink_account
        else
          link_account
        end
      end

      private

      def link_account
        # AU region: try ozfortress API first for automatic linking
        if Config.region_key == "au" && try_ozfortress_link
          return
        end

        # Fall back to manual web-based linking
        link_url = "#{Config.link_base_url}/discord/link"

        respond_with_embed({
          title: "Link your Discord to #{SITE_HOST}",
          description: "Click the link below to securely link your accounts.\n\n" \
            "This will:\n" \
            "1. Verify your Discord account\n" \
            "2. Link to your #{SITE_HOST} account\n\n" \
            "**[Click here to link your account](#{link_url})**",
          color: 0x5865F2
        })
      end

      def try_ozfortress_link
        steam_uid = OzfortressApi.steam_id_for_discord(discord_uid)
        return false unless steam_uid

        user = User.find_by(uid: steam_uid)
        return false unless user

        # Check if already linked to this Discord account
        if user.discord_uid == discord_uid
          respond_with_embed({
            title: "Already linked",
            description: "Your Discord is already linked to **#{user.nickname}** on #{SITE_HOST}.",
            color: 0x57F287
          })
          return true
        end

        # Check if Discord is linked to a different account
        if user.discord_uid.present?
          # Discord ID already linked to someone else, don't auto-link
          return false
        end

        # Auto-link via ozfortress
        user.update!(discord_uid: discord_uid)

        respond_with_embed({
          title: "Account linked via ozfortress",
          description: "Your Discord has been automatically linked to **#{user.nickname}** on #{SITE_HOST}.\n\n" \
            "This was possible because your accounts are already connected on ozfortress.com.",
          color: 0x57F287
        })
        true
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "OzfortressApi auto-link failed: #{e.message}"
        false
      end

      def unlink_account
        user = User.find_by(discord_uid: discord_uid)

        unless user
          respond_with_embed({
            title: "Not linked",
            description: "Your Discord account is not linked to any #{SITE_HOST} account.",
            color: 0xFFA500
          })
          return
        end

        user.update!(discord_uid: nil)

        respond_with_embed({
          title: "Discord unlinked",
          description: "Your Discord account has been unlinked from **#{user.nickname}** on #{SITE_HOST}.\n\n" \
            "You can re-link anytime using `/#{Config.command_name} link`.",
          color: 0x57F287
        })
      end
    end
  end
end
