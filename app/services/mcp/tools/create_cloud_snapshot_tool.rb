# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class CreateCloudSnapshotTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "create_cloud_snapshot"
      end

      sig { override.returns(String) }
      def self.description
        "Create a new Hetzner snapshot with the latest Docker image pre-pulled, " \
        "and delete old snapshots. This speeds up cloud server provisioning by " \
        "avoiding the Docker image pull on each boot. Runs as a background job."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            location: {
              type: "string",
              description: "Hetzner location code for the snapshot VM. Default: fsn1",
              default: "fsn1",
              enum: CloudProvider::Hetzner::LOCATIONS.keys
            }
          }
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        location = params.fetch(:location, "fsn1")

        unless CloudProvider::Hetzner::LOCATIONS.key?(location)
          return { error: "Unknown Hetzner location: #{location}" }
        end

        CloudSnapshotWorker.perform_async("hetzner", location)

        { status: "queued", provider: "hetzner", location: location, message: "Hetzner snapshot creation queued in #{location}. Old snapshots will be cleaned up automatically." }
      end
    end
  end
end
