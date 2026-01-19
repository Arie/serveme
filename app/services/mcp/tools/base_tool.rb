# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class BaseTool
      extend T::Sig

      sig { returns(String) }
      def self.tool_name
        raise NotImplementedError, "Subclasses must implement .tool_name"
      end

      sig { returns(String) }
      def self.description
        raise NotImplementedError, "Subclasses must implement .description"
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        raise NotImplementedError, "Subclasses must implement .input_schema"
      end

      sig { returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { params(user: User).returns(T::Boolean) }
      def self.available_to?(user)
        case required_role
        when :public
          true
        when :admin
          user.admin?
        when :league_admin
          user.admin? || user.league_admin?
        when :config_admin
          user.admin? || user.league_admin? || user.config_admin?
        else
          false
        end
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def self.to_mcp_definition
        {
          name: tool_name,
          description: description,
          inputSchema: input_schema
        }
      end

      sig { params(user: User).void }
      def initialize(user)
        @user = user
      end

      sig { params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        raise NotImplementedError, "Subclasses must implement #execute"
      end

      private

      sig { returns(User) }
      attr_reader :user
    end
  end
end
