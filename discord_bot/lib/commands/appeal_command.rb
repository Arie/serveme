# typed: false
# frozen_string_literal: true

module ServemeBot
  module Commands
    class AppealCommand < BaseCommand
      def execute
        log_command("appeal")

        return unless require_serveme_guild!
        return unless require_linked_account!

        steam_uid = current_user.uid

        # Check for open appeal
        open_appeal = redis_get("ban_appeal_open:#{steam_uid}")
        if open_appeal
          thread_id = open_appeal.split(":").first
          respond_with_error("You already have an open appeal: <##{thread_id}>")
          return
        end

        # Check cooldown
        cooldown_ttl = redis_ttl("ban_appeal_cooldown:#{steam_uid}")
        if cooldown_ttl > 0
          hours = (cooldown_ttl / 3600.0).ceil
          respond_with_error("Please wait #{hours} #{'hour'.pluralize(hours)} before submitting another appeal.")
          return
        end

        # Defer response since worker will update it
        event.respond(content: ":hourglass: Creating your ban appeal...", ephemeral: true)

        DiscordBanAppealWorker.perform_async(
          current_user.id,
          discord_uid,
          event.interaction.token
        )
      end

      private

      def require_serveme_guild!
        guild_id = Config.serveme_guild_id || Config.dev_guild_id
        if guild_id && event.server_id.to_s != guild_id.to_s
          respond_with_error("Ban appeals are only available in the serveme.tf Discord server.")
          return false
        end
        true
      end

      def redis_get(key)
        Sidekiq.redis { |redis| redis.get(key) }
      end

      def redis_ttl(key)
        Sidekiq.redis { |redis| redis.ttl(key) }
      end
    end
  end
end
