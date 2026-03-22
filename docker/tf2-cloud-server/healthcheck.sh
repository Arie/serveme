#!/bin/bash
# Docker healthcheck: verify SRCDS is responsive via RCON status command
PORT="${PORT:-27015}"
RCON_PASSWORD="${RCON_PASSWORD:-changeme}"

output=$("$HOME/hlserver/rcon" -H 127.0.0.1 -p "$PORT" -P "$RCON_PASSWORD" status 2>&1)
if [ $? -ne 0 ]; then
    echo "RCON status failed"
    exit 1
fi

# Verify we got a valid response (hostname line is always present in status output)
if echo "$output" | grep -q "hostname"; then
    exit 0
else
    echo "RCON status returned unexpected output"
    exit 1
fi
