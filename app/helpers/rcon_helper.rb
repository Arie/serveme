# frozen_string_literal: true

module RconHelper
  def rcon_commands
    [
      { command: 'say', description: 'Sends a message to all players', example: 'say "Hello World!"' },
      { command: 'kick', description: 'Kicks a player', example: 'kick "Player Name"' },
      { command: 'kickid', description: 'Kicks a player by ID', example: 'kickid "[U:1:373739847]"' },
      { command: 'restart', description: 'Restarts the map', example: 'restart' },
      { command: '_restart', description: 'Reboots the server', example: '_restart' },
      { command: 'sv_password', description: 'Changes the server password', example: 'sv_password "newpassword"' },
      { command: 'tv_password', description: 'Changes the stv password', example: 'tv_password "newpassword"' }
    ]
  end

  def clean_rcon(rcon_command)
    rcon_command.gsub(/^\s*!?rcon\ /, '').gsub(/^\s*map\ /, 'changelevel ')
  end
end
