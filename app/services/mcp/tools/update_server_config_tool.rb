# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class UpdateServerConfigTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "update_server_config"
      end

      sig { override.returns(String) }
      def self.description
        "Update a server config's visibility. Admin only. " \
        "Can only toggle the hidden flag - use this to show/hide configs from users."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            id: {
              type: "integer",
              description: "Config ID to update"
            },
            file: {
              type: "string",
              description: "Config filename to find (alternative to id)"
            },
            hidden: {
              type: "boolean",
              description: "Set the hidden status"
            }
          },
          required: [ "hidden" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        config = find_config(params)
        return { success: false, error: "Config not found" } unless config

        hidden = params[:hidden]
        return { success: false, error: "hidden parameter is required" } if hidden.nil?

        config.update!(hidden: hidden)

        {
          success: true,
          config: {
            id: config.id,
            file: config.file,
            hidden: config.hidden
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        {
          success: false,
          error: e.message
        }
      end

      private

      sig { params(params: T::Hash[Symbol, T.untyped]).returns(T.nilable(ServerConfig)) }
      def find_config(params)
        if params[:id].present?
          ServerConfig.find_by(id: params[:id])
        elsif params[:file].present?
          ServerConfig.find_by("lower(file) = ?", params[:file].to_s.downcase)
        end
      end
    end
  end
end
