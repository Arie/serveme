# typed: strict
# frozen_string_literal: true

require "shellwords"

module CloudProvider
  # Single source of truth for the env-var contract the tf2-cloud-server
  # container expects. Two modes:
  #
  #   :vm    — one container per VM (Hetzner/Vultr/Kamatera cloud-init).
  #            SSH_PORT is fixed at 2222 and no game-port offsets are emitted
  #            because the container uses the default 27015 set.
  #   :multi — many containers share a host (Docker/RemoteDocker). Each
  #            container gets a port-offset slot derived from its game port.
  class ContainerEnv
    extend T::Sig

    DEFAULT_VM_SSH_PORT = "2222"

    sig { params(cloud_server: CloudServer, ssh_public_key: T.nilable(String), mode: Symbol).returns(T::Hash[String, T.untyped]) }
    def self.build(cloud_server, ssh_public_key:, mode:)
      new(cloud_server, ssh_public_key, mode).build
    end

    # Renders the env hash as ["-e", "K=V"] argv pairs for system(*argv).
    sig { params(env: T::Hash[String, T.untyped]).returns(T::Array[String]) }
    def self.to_argv_pairs(env)
      env.flat_map { |k, v| [ "-e", "#{k}=#{v}" ] }
    end

    # Renders the env hash as shell-quoted "-e K=V" tokens for SSH/heredoc use.
    # Only the value is escaped, so "K=V" stays grep-able.
    sig { params(env: T::Hash[String, T.untyped]).returns(T::Array[String]) }
    def self.to_shell_args(env)
      env.map { |k, v| "-e #{k}=#{Shellwords.shellescape(v)}" }
    end

    sig { params(cloud_server: CloudServer, ssh_public_key: T.nilable(String), mode: Symbol).void }
    def initialize(cloud_server, ssh_public_key, mode)
      @cloud_server = cloud_server
      @ssh_public_key = ssh_public_key
      @mode = mode
      @discord_webhook = T.let(nil, T.nilable(String))
    end

    sig { returns(T::Hash[String, T.untyped]) }
    def build
      env = {
        "CALLBACK_URL"        => callback_url,
        "CALLBACK_TOKEN"      => @cloud_server.cloud_callback_token,
        "SSH_AUTHORIZED_KEYS" => @ssh_public_key,
        "RCON_PASSWORD"       => @cloud_server.rcon
      }
      env.merge!(port_env)
      env["ENABLE_FAKEIP"] = "1"
      env["EXPECTED_TF2_VERSION"] = Server.latest_version.to_s
      env["DISCORD_STAC_WEBHOOK_URL"] = discord_webhook if discord_webhook.present?
      env
    end

    private

    sig { returns(T::Hash[String, String]) }
    def port_env
      case @mode
      when :vm
        { "SSH_PORT" => DEFAULT_VM_SSH_PORT }
      when :multi
        game = @cloud_server.port.to_i
        offset = (game - 27015) / 10
        {
          "PORT"        => game.to_s,
          "TV_PORT"     => (game + 5).to_s,
          "SSH_PORT"    => (22000 + offset).to_s,
          "CLIENT_PORT" => (40001 + offset).to_s,
          "STEAM_PORT"  => (30001 + offset).to_s
        }
      else
        raise ArgumentError, "unknown ContainerEnv mode: #{@mode.inspect}"
      end
    end

    sig { returns(String) }
    def callback_url
      if ENV["CLOUD_CALLBACK_HOST"]
        "http://#{ENV['CLOUD_CALLBACK_HOST']}/api/cloud_servers/#{@cloud_server.id}/ready"
      else
        "https://#{SITE_HOST}/api/cloud_servers/#{@cloud_server.id}/ready"
      end
    end

    sig { returns(T.nilable(String)) }
    def discord_webhook
      @discord_webhook ||= ENV["DISCORD_STAC_WEBHOOK_URL"] ||
                           Rails.application.credentials.dig(:discord, :stac_webhook_url)
    end
  end
end
