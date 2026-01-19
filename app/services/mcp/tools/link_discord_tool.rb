# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class LinkDiscordTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "link_discord"
      end

      sig { override.returns(String) }
      def self.description
        "Link a Discord account to a serveme.tf user account. " \
        "The Discord bot calls this after verifying the user's Steam connection in Discord. " \
        "Once linked, users can use Discord commands without re-verification."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            discord_uid: {
              type: "string",
              description: "Discord user ID"
            },
            steam_uid: {
              type: "string",
              description: "Steam ID64 (from Discord's Steam connection)"
            },
            unlink: {
              type: "boolean",
              description: "If true, removes the Discord link instead of creating it",
              default: false
            }
          },
          required: [ "discord_uid", "steam_uid" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        discord_uid = params[:discord_uid]&.to_s&.strip
        steam_uid = params[:steam_uid]&.to_s&.strip
        unlink = params[:unlink] == true

        return { success: false, error: "discord_uid is required" } if discord_uid.blank?
        return { success: false, error: "steam_uid is required" } if steam_uid.blank?

        target_user = User.find_by(uid: steam_uid)
        return { success: false, error: "User not found for Steam ID: #{steam_uid}" } unless target_user

        if unlink
          return unlink_discord(target_user, discord_uid)
        end

        link_discord(target_user, discord_uid)
      end

      private

      sig { params(target_user: User, discord_uid: String).returns(T::Hash[Symbol, T.untyped]) }
      def link_discord(target_user, discord_uid)
        # Check if discord_uid is already linked to a different user
        existing_link = User.where(discord_uid: discord_uid).where.not(id: target_user.id).first
        if existing_link
          return {
            success: false,
            error: "Discord account already linked to another user (#{existing_link.nickname})"
          }
        end

        target_user.update!(discord_uid: discord_uid)

        {
          success: true,
          message: "Discord account linked successfully",
          user: format_user(target_user)
        }
      end

      sig { params(target_user: User, discord_uid: String).returns(T::Hash[Symbol, T.untyped]) }
      def unlink_discord(target_user, discord_uid)
        # Verify the discord_uid matches before unlinking
        if target_user.discord_uid != discord_uid
          return {
            success: false,
            error: "Discord account mismatch - cannot unlink"
          }
        end

        target_user.update!(discord_uid: nil)

        {
          success: true,
          message: "Discord account unlinked successfully",
          user: format_user(target_user)
        }
      end

      sig { params(target_user: User).returns(T::Hash[Symbol, T.untyped]) }
      def format_user(target_user)
        {
          id: target_user.id,
          nickname: target_user.nickname,
          steam_uid: target_user.uid,
          discord_uid: target_user.discord_uid,
          steam_profile_url: "https://steamcommunity.com/profiles/#{target_user.uid}"
        }
      end
    end
  end
end
