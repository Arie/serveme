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
        "Creates a CloudImageBuild record, then a background worker pulls the latest base image, " \
        "rebuilds with current plugins/configs, and pushes to Docker Hub. " \
        "Plugins and league configs are always refreshed; pass no_cache=true to also rebuild " \
        "SourceMod/MetaMod from scratch (the TF2 game files stay cached). " \
        "Only runs on the EU region (serveme.tf)."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        {
          type: "object",
          properties: {
            no_cache: {
              type: "boolean",
              description: "Rebuild SourceMod/MetaMod, plugins and configs from scratch. The cached TF2 game files are kept. Defaults to false."
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
        return { error: "Only available on the EU region (serveme.tf)" } unless SITE_HOST == "serveme.tf"

        version = Server.latest_version
        return { error: "Could not fetch latest TF2 version from Steam API" } unless version

        no_cache = ActiveModel::Type::Boolean.new.cast(params[:no_cache]) || false
        build = CloudImageBuild.create!(version: version.to_s, force_pull: false, no_cache: no_cache, status: "queued")
        CloudImageBuildWorker.perform_async(build.id)
        CloudImageBuild.broadcast_history

        { status: "queued", build_id: build.id, version: version, no_cache: no_cache, message: "Cloud image build queued for TF2 version #{version}" }
      end
    end
  end
end
