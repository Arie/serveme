# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class BuildCloudImageTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "build_cloud_image"
      end

      sig { override.returns(String) }
      def self.description
        "Build and push a new TF2 cloud server Docker image. " \
        "Triggers a background build on the EU server that pulls the latest base image, " \
        "rebuilds with current plugins/configs, and pushes to Docker Hub. " \
        "Only runs on the EU region (serveme.tf)."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {}
        }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        return { error: "Only available on the EU region (serveme.tf)" } unless SITE_HOST == "serveme.tf"

        version = Server.latest_version
        return { error: "Could not fetch latest TF2 version from Steam API" } unless version

        CloudImageBuildWorker.perform_async(version)

        { status: "queued", version: version, message: "Cloud image build queued for TF2 version #{version}" }
      end
    end
  end
end
