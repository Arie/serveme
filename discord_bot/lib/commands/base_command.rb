# typed: false
# frozen_string_literal: true

module ServemeBot
  module Commands
    class BaseCommand
      attr_reader :event

      def initialize(event)
        @event = event
      end

      def discord_uid
        event.user.id.to_s
      end

      def discord_username
        event.user.username
      end

      def current_user
        @current_user ||= User.find_by(discord_uid: discord_uid)
      end

      def log_command(command_name, **options)
        user_info = current_user ? "#{current_user.nickname} (#{current_user.id})" : "unlinked"
        options_str = options.any? ? " #{options.inspect}" : ""
        Rails.logger.info "[Discord] #{command_name} by #{discord_username} (#{discord_uid}) -> #{user_info}#{options_str}"
      end

      def require_linked_account!
        return true if current_user

        # AU region: try ozfortress auto-link before showing error
        if Config.region_key == "au" && try_ozfortress_auto_link
          return true
        end

        respond_with_error(
          "Your Discord account is not linked to #{SITE_HOST}.\n\n" \
          "Use `/#{ServemeBot::Config.command_name} link` to connect your accounts."
        )
        false
      end

      def respond_with_embed(embed)
        event.respond(embeds: [ embed ])
      end

      def respond_with_error(message)
        event.respond(content: ":x: #{message}", ephemeral: true)
      end

      def respond_with_success(message)
        event.respond(content: ":white_check_mark: #{message}")
      end

      def defer_response
        event.defer if event.respond_to?(:defer)
      end

      def edit_response(content: nil, embeds: nil, components: nil)
        if event.respond_to?(:edit_response)
          event.edit_response(content: content, embeds: embeds, components: components)
        else
          event.respond(content: content, embeds: embeds, components: components)
        end
      end

      private

      def try_ozfortress_auto_link
        steam_uid = OzfortressApi.steam_id_for_discord(discord_uid)
        return false unless steam_uid

        user = User.find_by(uid: steam_uid)
        return false unless user
        return false if user.discord_uid.present? # Already linked to someone

        user.update!(discord_uid: discord_uid)
        @current_user = user # Update cached user
        Rails.logger.info "[Discord] Auto-linked #{discord_username} (#{discord_uid}) via ozfortress -> #{user.nickname} (#{user.id})"
        true
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "OzfortressApi auto-link failed: #{e.message}"
        false
      end
    end
  end
end
