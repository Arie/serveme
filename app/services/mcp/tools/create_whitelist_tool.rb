# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class CreateWhitelistTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "create_whitelist"
      end

      sig { override.returns(String) }
      def self.description
        "Create a new whitelist. Admin only. " \
        "The whitelist must exist on whitelist.tf - this just registers it in the system."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            file: {
              type: "string",
              description: "Whitelist name (e.g., 'etf2l_whitelist_6v6')"
            },
            hidden: {
              type: "boolean",
              description: "Whether the whitelist should be hidden from users. Default: false",
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

        # Check if whitelist already exists
        existing = Whitelist.find_by("lower(file) = ?", file.downcase)
        if existing
          return {
            success: false,
            error: "Whitelist '#{file}' already exists (id: #{existing.id})"
          }
        end

        whitelist = Whitelist.create!(file: file, hidden: hidden)

        {
          success: true,
          whitelist: {
            id: whitelist.id,
            file: whitelist.file,
            hidden: whitelist.hidden
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
