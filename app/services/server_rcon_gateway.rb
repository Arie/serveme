# typed: true
# frozen_string_literal: true

# Owns a server's RCON connection and command execution. Extracted from Server so
# the model stays focused on persistence; Server delegates rcon_exec/rcon_say/
# rcon_auth/rcon_disconnect/condenser here. A condenser can be injected for tests.
class ServerRconGateway
  extend T::Sig

  BLOCKED_COMMANDS = %w[logaddress rcon_password sv_downloadurl].freeze

  sig { params(server: Server, condenser: T.untyped).void }
  def initialize(server, condenser: nil)
    @server = server
    @condenser = condenser
    @rcon_auth = nil
  end

  sig { returns(T.untyped) }
  def condenser
    @condenser ||= SteamCondenser::Servers::SourceServer.new(@server.ip, @server.port.to_i)
  end

  sig { params(rcon: T.untyped).returns(T.untyped) }
  def auth(rcon = @server.current_rcon)
    @rcon_auth ||= condenser.rcon_auth(rcon)
  rescue NoMethodError # Empty rcon reply, typically due to rcon ban
    nil
  end

  sig { params(message: String).returns(T::Array[T.untyped]) }
  def say(message)
    message.split("\n").flat_map do |line|
      T.cast(line.scan(/.{1,200}(?:\s|$)/), T::Array[String]).map(&:strip).map { |chunk| exec("say #{chunk}") }
    end
  end

  sig { params(command: String, allow_blocked: T::Boolean).returns(T.untyped) }
  def exec(command, allow_blocked: false)
    command = escape_comment_markers(command)
    return nil if blocked_command?(command) && !allow_blocked

    condenser.rcon_exec(command) if auth
  rescue Errno::ECONNREFUSED, SteamCondenser::Error::Timeout, SteamCondenser::Error::RCONNoAuth, SteamCondenser::Error::RCONBan => e
    Rails.logger.error "Couldn't deliver command to server #{@server.id} - #{@server.name}, command: #{command}, exception: #{e}"
    nil
  end

  sig { void }
  def disconnect
    condenser.disconnect
  rescue StandardError => e
    Rails.logger.error "Couldn't disconnect RCON of server #{@server.id} - #{@server.name}, exception: #{e}"
  ensure
    @condenser = nil
  end

  sig { params(command: String).returns(T::Boolean) }
  def blocked_command?(command)
    BLOCKED_COMMANDS.any? { |c| command.downcase.include?(c) }
  end

  private

  # Escape // with a zero-width space so the Source engine doesn't treat it as a
  # comment, but preserve URLs inside quoted strings (like sm_web_rcon_url "https://...").
  sig { params(command: String).returns(String) }
  def escape_comment_markers(command)
    command.gsub(%r{//}) do |match|
      last_match = T.must(Regexp.last_match)
      before_match = last_match.pre_match
      quotes_before = before_match.scan(/"/).length
      quotes_before.odd? ? match : "/\u200B/"
    end
  end
end
