# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class UpdateWhitelistTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "update_whitelist"
      end

      sig { override.returns(String) }
      def self.description
        "Update a whitelist's visibility. Admin only. " \
        "Can only toggle the hidden flag - use this to show/hide whitelists from users."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            id: {
              type: "integer",
              description: "Whitelist ID to update"
            },
            file: {
              type: "string",
              description: "Whitelist name to find (alternative to id)"
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
        whitelist = find_whitelist(params)
        return { success: false, error: "Whitelist not found" } unless whitelist

        hidden = params[:hidden]
        return { success: false, error: "hidden parameter is required" } if hidden.nil?

        whitelist.update!(hidden: hidden)

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

      private

      sig { params(params: T::Hash[Symbol, T.untyped]).returns(T.nilable(Whitelist)) }
      def find_whitelist(params)
        if params[:id].present?
          Whitelist.find_by(id: params[:id])
        elsif params[:file].present?
          Whitelist.find_by("lower(file) = ?", params[:file].to_s.downcase)
        end
      end
    end
  end
end
