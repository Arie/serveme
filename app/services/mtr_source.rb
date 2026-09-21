# typed: true
# frozen_string_literal: true

# One physical machine an mtr can be run from: all SshServers sharing an ip
# collapse into one source, and a DockerHost on the same box is not listed twice.
class MtrSource
  extend T::Sig

  SSH_SERVER = "ssh_server"
  DOCKER_HOST = "docker_host"
  SSH_OPTIONS = { timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2, bind_address: "0.0.0.0" }.freeze

  attr_reader :type, :key, :label, :detail, :flag

  sig { params(type: String, key: String, label: String, detail: String, flag: T.nilable(String), docker_host: T.nilable(DockerHost)).void }
  def initialize(type:, key:, label:, detail:, flag:, docker_host: nil)
    @type = type
    @key = key
    @label = label
    @detail = detail
    @flag = flag
    @docker_host = docker_host
  end

  class << self
    extend T::Sig

    sig { returns(T::Array[MtrSource]) }
    def all
      ssh = ssh_sources
      taken = ssh.map(&:label)
      ssh + docker_sources.reject { |s| taken.include?(s.label) || taken.include?(s.docker_host_ip) }
    end

    sig { params(type: T.nilable(String), key: T.nilable(String)).returns(T.nilable(MtrSource)) }
    def find(type, key)
      all.find { |s| s.type == type && s.key == key.to_s }
    end

    sig { params(id: String).returns(T.nilable(MtrSource)) }
    def find_by_id(id)
      type, key = id.split(":", 2)
      find(type, key)
    end

    private

    def ssh_sources
      docker_names = DockerHost.active.pluck(:hostname, :ip).flatten.compact
      SshServer.active.includes(:location).where.not(ip: nil).group_by { |s| T.must(s.ip) }.map do |ip, servers|
        detail = "SSH host · #{servers.size} #{'server'.pluralize(servers.size)}"
        detail += " + Docker host" if docker_names.include?(ip)
        new(type: SSH_SERVER, key: ip, label: ip, detail: detail, flag: T.must(servers.first).location&.flag)
      end.sort_by(&:label)
    end

    def docker_sources
      DockerHost.active.includes(:location).order(:hostname).map do |dh|
        new(type: DOCKER_HOST, key: dh.id.to_s, label: dh.hostname, detail: "Docker host · #{dh.city}", flag: dh.location&.flag, docker_host: dh)
      end
    end
  end

  sig { returns(String) }
  def id
    "#{type}:#{key}"
  end

  sig { returns(T.nilable(String)) }
  def docker_host_ip
    @docker_host&.ip
  end

  sig { returns(String) }
  def short_label
    T.must(label.split(".").first)
  end

  # Yields output chunks as they arrive; returns the remote exit status.
  sig { params(command: String, block: T.proc.params(stream: Symbol, data: String).void).returns(T.nilable(Integer)) }
  def stream(command, &block)
    exit_status = T.let(nil, T.nilable(Integer))
    with_ssh do |ssh|
      channel = ssh.open_channel do |ch|
        ch.exec(command) do |c, ok|
          raise "ssh exec failed" unless ok

          c.on_data { |_, data| yield :stdout, data }
          c.on_extended_data { |_, _, data| yield :stderr, data }
          c.on_request("exit-status") { |_, data| exit_status = data.read_long }
        end
      end
      channel.wait
    end
    exit_status
  end

  private

  def with_ssh(&block)
    return @docker_host.with_ssh(&block) if @docker_host

    Net::SSH.start(key, nil, **SSH_OPTIONS, &block)
  end
end
