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

      # Admins and trusted API users (e.g. Discord bots) can act on behalf of other users.
      # Regular users can only act on their own resources.
      sig { returns(T::Boolean) }
      def privileged?
        user.admin? || user.trusted_api?
      end

      # Resolve the target user from params. Privileged callers can specify steam_uid/discord_uid
      # to act on behalf of another user. Non-privileged callers always get @user.
      sig { params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def resolve_target_user(params)
        if privileged?
          if params[:discord_uid].present?
            target = User.find_by(discord_uid: params[:discord_uid])
            return { error: "Discord account not linked" } unless target
            { user: target }
          elsif params[:steam_uid].present?
            target = User.find_by(uid: params[:steam_uid])
            return { error: "No account found for Steam ID: #{params[:steam_uid]}" } unless target
            { user: target }
          else
            { user: user }
          end
        else
          { user: user }
        end
      end

      # Verify the API user owns a reservation. Privileged callers can access any reservation.
      sig { params(reservation: Reservation).returns(T::Hash[Symbol, T.untyped]) }
      def verify_reservation_owner(reservation)
        return {} if privileged?
        return { error: "Not authorized to access this reservation" } unless reservation.user_id == user.id
        {}
      end
    end
  end
end
