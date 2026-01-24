# serveme.tf Regional MCP Servers

serveme.tf provides MCP (Model Context Protocol) servers for each geographic region, enabling direct access to user, server, and reservation data. Each region operates independently with its own database.

## Available Regions

| MCP Server | Region | Domain |
|------------|--------|--------|
| `serveme-eu` | Europe | serveme.tf |
| `serveme-na` | North America | na.serveme.tf |
| `serveme-au` | Australia | au.serveme.tf |
| `serveme-sea` | Southeast Asia | sea.serveme.tf |

## Tool Reference

### User & Account Management

#### `get_user`
Look up detailed user information by various identifiers.

**Parameters:**
- `query` (required): Steam ID64, Steam ID, Steam ID3, user ID (#123), Steam profile URL, or nickname

**Returns:** User details including reservation history, donator status, group memberships.

**Example queries:**
- `76561198012345678` (Steam ID64)
- `STEAM_0:0:123456` (Steam ID)
- `[U:1:123456]` (Steam ID3)
- `#42` or `42` (user ID)
- `https://steamcommunity.com/id/username`

#### `search_alts`
Find alternate accounts by IP address or Steam ID cross-referencing. Supports batch searches with multiple Steam IDs.

**Parameters:**
- `steam_uid`: Steam ID(s) to search - accepts single ID, comma-separated string, or array
- `ip`: IP address to search
- `cross_reference` (default: true): Find all accounts sharing IPs
- `reservation_ids`: Comma-separated list to limit search scope

**Use cases:**
- Investigating ban evasion
- Finding shared accounts
- Batch searching multiple known alts to find more connections
- Tracing suspicious activity

#### `search_by_asn`
Find accounts from a specific ISP/ASN. Useful for detecting alt accounts from the same network provider.

**Parameters:**
- `asn_number` (required): ASN number (e.g., 8708 for Digi Romania)
- `days` (default: 90): Search window in days
- `limit` (default: 50): Maximum accounts to return


#### `link_discord` / `get_discord_link`
Manage Discord-to-Steam account linking for bot integration.

**link_discord parameters:**
- `discord_uid` (required): Discord user ID
- `steam_uid` (required): Steam ID64
- `unlink` (default: false): Remove link instead of creating

**get_discord_link parameters:**
- `discord_uid` (required): Discord user ID to look up

### Server Management

#### `list_servers`
List all game servers with current status (admin tool).

**Parameters:**
- `active_only` (default: true): Only return active servers
- `include_reservation` (default: false): Include current reservation info

**Returns:** Server details including location, IP, port, and optionally reservation data.

#### `get_public_servers`
Public endpoint for server availability (no sensitive data).

**Parameters:**
- `location`: Filter by location name (e.g., 'Netherlands', 'Chicago')

**Returns:** Basic server info suitable for public display.

### Reservation Management

#### `list_reservations`
Admin view of reservations with full details including passwords and RCON.

**Parameters:**
- `status`: Filter by `current`, `future`, `past`, or `all`
- `user_query`: Find user by Steam URL, ID, nickname
- `user_id`: Filter by user ID
- `steam_uid`: Filter by Steam ID64
- `server_id`: Filter by server ID
- `limit` (default: 25): Maximum results

**Security:** Returns RCON passwords - use only for admin tasks.

#### `get_player_reservations`
Player's own reservation history (safe for Discord bot).

**Parameters:**
- `steam_uid`: Steam ID64 of the player
- `discord_uid`: Discord user ID (for bot integration)
- `status`: Filter by `current`, `future`, `past`, or `all`
- `limit` (default: 25): Maximum results

**Security:** No passwords or RCON - safe for user-facing features.

#### `create_reservation`
Create a new server reservation.

**Parameters:**
- `password` (required): Server password
- `steam_uid` or `discord_uid`: User identification
- `server_id`: Specific server (auto-selects if omitted)
- `duration_minutes` (default: 120): Reservation length
- `first_map` (default: cp_badlands): Initial map
- `rcon`: RCON password (auto-generated if omitted)
- `server_config_id`: Config to apply
- `whitelist_id`: Whitelist to apply
- `enable_plugins`: Enable SourceMod
- `enable_demos_tf`: Enable demos.tf recording

**Returns:** Reservation details including server IP, password, and RCON.

#### `get_reservation_status`
Get live status of an active reservation.

**Parameters:**
- `reservation_id` (required): Reservation ID
- `steam_uid` or `discord_uid`: For authorization

**Returns:** Server status, connected players, time remaining.

#### `end_reservation`
End an active reservation early.

**Parameters:**
- `reservation_id` (required): Reservation ID to end
- `steam_uid` or `discord_uid`: For authorization

## Usage Patterns

### Discord Bot Integration
```
1. Use get_discord_link to check if user is linked
2. If not linked, prompt user to link via link_discord
3. Use discord_uid parameter for reservation operations
4. Use get_player_reservations (not list_reservations) for user-facing data
```

### Admin Investigation
```
1. Use get_user to look up a player
2. Use search_alts to find alternate accounts
3. Use search_by_asn for ISP-wide searches
4. Use list_reservations with user_query for full history
```

### Server Booking Flow
```
1. Use get_public_servers to show available servers
2. Use create_reservation with user's steam_uid
3. Use get_reservation_status for live updates
4. Use end_reservation when done
```

## Important Notes

- **Region-specific data:** Users and servers exist only in their region. Query the appropriate regional server.
- **Steam ID formats:** All tools accept any Steam ID format and convert automatically. Never manually convert between formats.
- **Authorization:** Reservation operations require matching steam_uid or discord_uid for the reservation owner.
- **Rate limiting:** MCP servers have rate limits. Batch operations where possible.
