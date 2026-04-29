# typed: strict
# frozen_string_literal: true

module Mcp
  module Tools
    class BuildCaddyCloudflareImageTool < BaseTool
      extend T::Sig

      sig { override.returns(String) }
      def self.tool_name
        "build_caddy_cloudflare_image"
      end

      sig { override.returns(String) }
      def self.description
        "Build and push the serveme/caddy-cloudflare Docker image used by every docker host's compose stack. " \
        "Triggers a background build on the EU server that pulls the latest caddy:2 base, " \
        "compiles the caddy-dns/cloudflare module, and pushes :latest to Docker Hub. " \
        "Hosts pick up the new image the next time `provision` is run on them. " \
        "Only runs on the EU region (serveme.tf)."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def self.input_schema
        { type: "object", properties: {} }
      end

      sig { override.returns(Symbol) }
      def self.required_role
        :admin
      end

      sig { override.params(params: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def execute(params)
        return { error: "Only available on the EU region (serveme.tf)" } unless SITE_HOST == "serveme.tf"

        BuildCaddyCloudflareImageWorker.perform_async

        { status: "queued", message: "caddy-cloudflare image build queued" }
      end
    end
  end
end
