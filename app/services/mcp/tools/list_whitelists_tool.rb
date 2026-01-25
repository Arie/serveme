# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class ListWhitelistsTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "list_whitelists"
      end

      sig { override.returns(String) }
      def self.description
        "List available whitelists. " \
        "Non-admins see only visible whitelists, admins see all including hidden ones. " \
        "Use include_hidden parameter to filter."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Filter whitelists by name (case-insensitive partial match)"
            },
            include_hidden: {
              type: "boolean",
              description: "Include hidden whitelists (admin only). Default: false for non-admins, true for admins",
              default: false
            }
          }
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :public
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        # Non-admins can only see visible whitelists
        # Admins default to seeing all, but can filter to visible only
        include_hidden = params[:include_hidden]
        show_hidden = user.admin? && include_hidden != false

        whitelists = if show_hidden
          Whitelist.order("lower(file)")
        else
          Whitelist.where(hidden: false).order("lower(file)")
        end

        # Filter by name if query provided
        if params[:query].present?
          query = params[:query].to_s.downcase
          whitelists = whitelists.where("lower(file) LIKE ?", "%#{query}%")
        end

        formatted_whitelists = whitelists.map { |w| format_whitelist(w) }

        {
          whitelists: formatted_whitelists,
          whitelist_count: formatted_whitelists.size
        }
      end

      private

      sig { params(whitelist: Whitelist).returns(T::Hash[Symbol, T.untyped]) }
      def format_whitelist(whitelist)
        result = {
          id: whitelist.id,
          file: whitelist.file
        }

        # Only show hidden status to admins
        result[:hidden] = whitelist.hidden if user.admin?

        result
      end
    end
  end
end
