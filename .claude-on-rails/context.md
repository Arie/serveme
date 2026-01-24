# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Project Information
- **Rails Version**: 8.1.1
- **Ruby Version**: 4.0.0
- **Project Type**: Full-stack Rails
- **Test Framework**: RSpec (unit/integration tests) + Cucumber (acceptance tests)
- **Turbo/Stimulus**: Enabled
- **Template Engine**: HAML (primary), ERB (secondary)
- **Background Jobs**: Sidekiq workers (not ActiveJob)

## Agent Prompts

The `.claude-on-rails/prompts/` directory contains specialized prompts for different aspects of Rails development:
- **architect.md** - Overall system design and coordination
- **models.md** - ActiveRecord models and database design
- **controllers.md** - Request handling and routing
- **views.md** - Templates and presentation layer
- **services.md** - Business logic and service objects
- **tests.md** - RSpec and Cucumber testing
- **stimulus.md** - JavaScript controllers and Turbo integration
- **jobs.md** - Background job processing
- **api.md** - API endpoints and documentation
- **devops.md** - Deployment and infrastructure

## Per-Region MCP Servers

serveme.tf operates across multiple regions, each with its own MCP server providing direct access to region-specific data:

| Server | Region | Notes |
|--------|--------|-------|
| `serveme-eu` | Europe | Primary region |
| `serveme-na` | North America | |
| `serveme-au` | Australia | |
| `serveme-sea` | Southeast Asia | |

### Available Tools (per region)

**User & Account Management:**
- `get_user` - Look up user by Steam ID, nickname, or user ID
- `search_alts` - Find alternate accounts by IP or Steam ID
- `search_by_asn` - Find accounts by ISP/ASN (not available in SEA)
- `link_discord` / `get_discord_link` - Discord account linking

**Server Management:**
- `list_servers` - List all servers with status
- `get_public_servers` - Public server availability (no sensitive data)

**Reservation Management:**
- `list_reservations` - Admin view with passwords/RCON
- `get_player_reservations` - Player's own reservations (safe for Discord bot)
- `create_reservation` - Book a server
- `get_reservation_status` - Live reservation status with players
- `end_reservation` - End reservation early

### Usage Notes

- Always use the appropriate regional server (users/servers are region-specific)
- `list_reservations` returns sensitive data (RCON passwords) - use for admin tasks
- `get_player_reservations` is safe for Discord bot integration
- Steam IDs can be provided in any format (ID64, ID, ID3, profile URL)

See `.claude-on-rails/prompts/mcp-servers.md` for detailed documentation.

## Development Guidelines

When working on this project:
- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries