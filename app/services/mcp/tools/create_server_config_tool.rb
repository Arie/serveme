# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class CreateServerConfigTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "create_server_config"
      end

      sig { override.returns(String) }
      def self.description
        "Create a new server config. Admin only. " \
        "The config file must exist on the game servers - this just registers it in the system."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            file: {
              type: "string",
              description: "Config filename without .cfg extension (e.g., 'etf2l_6v6_5cp')"
            },
            hidden: {
              type: "boolean",
              description: "Whether the config should be hidden from users. Default: false",
              default: false
            }
          },
          required: [ "file" ]
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        file = params[:file].to_s.strip
        hidden = params[:hidden] || false

        # Check if config already exists
        existing = ServerConfig.find_by("lower(file) = ?", file.downcase)
        if existing
          return {
            success: false,
            error: "Config '#{file}' already exists (id: #{existing.id})"
          }
        end

        config = ServerConfig.create!(file: file, hidden: hidden)

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
    end
  end
end
