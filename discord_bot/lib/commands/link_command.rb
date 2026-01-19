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
