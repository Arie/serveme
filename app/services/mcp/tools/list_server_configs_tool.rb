# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class ListServerConfigsTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "list_server_configs"
      end

      sig { override.returns(String) }
      def self.description
        "List available server configs (exec configurations). " \
        "Non-admins see only visible configs, admins see all including hidden ones. " \
        "Use include_hidden parameter to filter."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Filter configs by name (case-insensitive partial match)"
            },
            include_hidden: {
              type: "boolean",
              description: "Include hidden configs (admin only). Default: false for non-admins, true for admins",
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
        # Non-admins can only see visible configs
        # Admins default to seeing all, but can filter to visible only
        include_hidden = params[:include_hidden]
        show_hidden = user.admin? && include_hidden != false

        configs = if show_hidden
          ServerConfig.order("lower(file)")
        else
          ServerConfig.where(hidden: false).order("lower(file)")
        end

        # Filter by name if query provided
        if params[:query].present?
          query = params[:query].to_s.downcase
          configs = configs.where("lower(file) LIKE ?", "%#{query}%")
        end

        formatted_configs = configs.map { |c| format_config(c) }

        {
          configs: formatted_configs,
          config_count: formatted_configs.size
        }
      end

      private

      sig { params(config: ServerConfig).returns(T::Hash[Symbol, T.untyped]) }
      def format_config(config)
        result = {
          id: config.id,
          file: config.file
        }

        # Only show hidden status to admins
        result[:hidden] = config.hidden if user.admin?

        result
      end
    end
  end
end
