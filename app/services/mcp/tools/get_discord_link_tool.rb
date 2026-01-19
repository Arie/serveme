# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class GetDiscordLinkTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "get_discord_link"
      end

      sig { override.returns(String) }
      def self.description
        "Resolve a Discord user ID to their linked Steam ID. " \
        "Used by the Discord bot to verify user identity. " \
        "Returns the Steam ID64 if the Discord account is linked."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            discord_uid: {
              type: "string",
              description: "Discord user ID to look up"
            }
          },
          required: [ "discord_uid" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        discord_uid = params[:discord_uid]&.to_s&.strip

        if discord_uid.blank?
          return { error: "discord_uid is required", linked: false }
        end

        linked_user = User.find_by(discord_uid: discord_uid)

        if linked_user
          {
            linked: true,
            steam_uid: linked_user.uid,
            user_id: linked_user.id,
            nickname: linked_user.nickname,
            steam_profile_url: "https://steamcommunity.com/profiles/#{linked_user.uid}"
          }
        else
          {
            linked: false,
            steam_uid: nil,
            message: "Discord account not linked. Use /link to connect your account."
          }
        end
      end
    end
  end
end
