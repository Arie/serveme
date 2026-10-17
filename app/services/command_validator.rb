# typed: true

require "set"

class CommandValidator
  extend T::Sig

  # ALLOWED_SERVER_COMMANDS is generated from everything the server knows, so
  # also refuse commands that run other commands (getting around this check)
  # or take serveme's control of the server away.
  DENIED_COMMANDS = Set.new(%w[
    alias sm_rcon script script_execute ent_fire
    rcon_password sv_rcon_banpenalty sv_rcon_maxfailures sv_rcon_minfailures sv_rcon_minfailuretime
    logaddress_add logaddress_add_http logaddress_del logaddress_delall sv_logsecret sv_downloadurl
  ]).freeze

  sig { params(command_string: T.nilable(String)).returns(T::Boolean) }
  def self.validate(command_string)
    return true unless command_string.present?

    unless defined?(ALLOWED_SERVER_COMMANDS)
      raise "CommandValidator Error: ALLOWED_SERVER_COMMANDS constant not defined. Initializer might have failed."
    end

    # The console treats newlines like ";"
    commands = command_string.split(/[;\r\n]/).map(&:strip).reject(&:empty?)

    commands.each do |full_command|
      base_command = full_command.split(" ", 2).first
      if !ALLOWED_SERVER_COMMANDS.include?(base_command) || DENIED_COMMANDS.include?(base_command.to_s.downcase)
        Rails.logger.warn("CommandValidator: Disallowed command '#{base_command}' found in string: '#{command_string}'")
        return false
      end
    end

    true
  end
end
