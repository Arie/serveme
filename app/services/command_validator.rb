# typed: true

require "set"

class CommandValidator
  def self.validate(command_string)
    return true unless command_string.present?

    unless defined?(ALLOWED_SERVER_COMMANDS)
      raise "CommandValidator Error: ALLOWED_SERVER_COMMANDS constant not defined. Initializer might have failed."
    end

    commands = command_string.split(";").map(&:strip).reject(&:empty?)

    commands.each do |full_command|
      base_command = full_command.split(" ", 2).first
      unless ALLOWED_SERVER_COMMANDS.include?(base_command)
        Rails.logger.warn("CommandValidator: Disallowed command '#{base_command}' found in string: '#{command_string}'")
        return false
      end
    end

    true
  end
end
