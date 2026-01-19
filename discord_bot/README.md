# serveme.tf Discord Bot

Discord bot for managing TF2 server reservations on serveme.tf.

## Features

- `/link` - Link Discord account to serveme.tf via OAuth
- `/reservations` - View your reservation history
- `/servers` - List available servers
- `/reserve` - Reserve a TF2 server with live status updates
- `/unlink` - Disconnect accounts

## Architecture

The bot loads the Rails environment directly and uses models/services to interact with the database. This is similar to how Sidekiq workers operate.

```
Discord User
     │
     ▼
Discord Bot
     │
     ▼
Rails Environment (models, services, database)
```

## Setup

### Prerequisites

- Ruby (same version as main Rails app)
- Redis
- PostgreSQL
- Discord bot token and client ID

### Configuration

Secrets are loaded from Rails credentials (`config/credentials.yml.enc`):

```yaml
discord:
  token: "your-bot-token"
  client_id: "your-client-id"
  client_secret: "your-client-secret"  # for OAuth
  dev_guild_id: "your-test-server-id"  # optional, for development
```

Or via environment variables:
- `DISCORD_TOKEN`
- `DISCORD_CLIENT_ID`
- `DISCORD_DEV_GUILD_ID` (development only)

## Running

### Development

```bash
# From the Rails root directory (not discord_bot/)
cd /path/to/serveme

# Start the bot
bundle exec ruby discord_bot/bot.rb

# Or use the helper script
discord_bot/bin/start

# With explicit environment
RAILS_ENV=development bundle exec ruby discord_bot/bot.rb
```

Development mode:
- Uses guild commands for instant updates (no 1-hour propagation delay)
- Link URL points to localhost

### Production

```bash
RAILS_ENV=production bundle exec ruby discord_bot/bot.rb
```

Or install as a systemd service:

```bash
sudo cp discord_bot/config/serveme-discord-bot.service /etc/systemd/system/
# Edit the service file to set RAILS_MASTER_KEY
sudo systemctl daemon-reload
sudo systemctl enable serveme-discord-bot
sudo systemctl start serveme-discord-bot
```

Production mode:
- Uses global commands (may take up to 1 hour to propagate)
- Link URL points to serveme.tf

## /reserve Command

The reserve command creates a server reservation and provides live status updates:

1. User runs `/reserve password:mypassword [duration:minutes] [map:cp_process_final]`
2. Bot finds an available server and creates the reservation
3. Bot sends an embed with server details (connect string, password, RCON)
4. Status updater polls every 30 seconds and updates the embed
5. Shows player list, time remaining, and server status
6. Embed updates to "Ended" when reservation expires

## Testing

```bash
# From Rails root
RAILS_ENV=test bundle exec rspec discord_bot/spec/
```

## Files

```
discord_bot/
├── bot.rb                    # Main entry point
├── bin/
│   └── start                 # Helper script
├── config/
│   └── serveme-discord-bot.service  # Systemd service
├── lib/
│   ├── config.rb             # Discord configuration
│   ├── status_updater.rb     # Live reservation updates
│   ├── commands/
│   │   ├── base_command.rb
│   │   ├── link_command.rb
│   │   ├── reserve_command.rb
│   │   ├── reservations_command.rb
│   │   └── servers_command.rb
│   └── formatters/
│       ├── reservation_formatter.rb
│       └── server_formatter.rb
└── spec/
    └── ...
```
