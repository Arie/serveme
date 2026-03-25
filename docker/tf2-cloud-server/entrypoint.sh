#!/bin/bash
set -e

# 1. Setup SSH for remote file management (config push, log/demo extraction)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -n "$SSH_AUTHORIZED_KEYS" ]; then
    echo "$SSH_AUTHORIZED_KEYS" > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi
SSH_PORT="${SSH_PORT:-22}"
sudo /usr/sbin/sshd -p "$SSH_PORT"

# Supervise sshd: restart it if it dies (check every 30s)
(
    while true; do
        sleep 30
        if ! ss -tln | grep -q ":${SSH_PORT}[[:space:]]"; then
            echo "sshd on port $SSH_PORT is down, restarting..."
            sudo /usr/sbin/sshd -p "$SSH_PORT"
        fi
    done
) &

# 2. Check if TF2 needs updating
if [ -n "$EXPECTED_TF2_VERSION" ]; then
    STEAM_INF="$HOME/hlserver/tf2/tf/steam.inf"
    if [ -f "$STEAM_INF" ]; then
        INSTALLED_VERSION=$(grep -oP 'PatchVersion=\K[0-9.]+' "$STEAM_INF" | tr -d '.')
    fi
    if [ "$INSTALLED_VERSION" != "$EXPECTED_TF2_VERSION" ]; then
        echo "TF2 outdated (installed: ${INSTALLED_VERSION:-unknown}, expected: $EXPECTED_TF2_VERSION), updating..."
        /usr/games/steamcmd +force_install_dir /home/tf2/hlserver/tf2 +login anonymous +app_update 232250 +quit || \
        /usr/games/steamcmd +force_install_dir /home/tf2/hlserver/tf2 +login anonymous +app_update 232250 +quit
        echo "TF2 update complete"
    else
        echo "TF2 is up to date (version: $INSTALLED_VERSION)"
    fi
fi

# 3. Remove plugins that conflict with serveme's config management
rm -f "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins/autoexec.smx"

# 4. Write server.cfg with rcon password and reservation.cfg exec
cat > "$HOME/hlserver/tf2/tf/cfg/server.cfg" <<SERVERCFG
hostname "serveme cloud server"
sv_downloadurl "https://fastdl.serveme.tf"
rcon_password "${RCON_PASSWORD:-changeme}"
log on
logaddress_delall
tv_autorecord 1
sv_rcon_minfailuretime 1
sv_rcon_minfailures 20
sv_rcon_maxfailures 20
sv_rcon_banpenalty 1
exec aliases.cfg
exec ctf_turbine.cfg
exec reservation.cfg
SERVERCFG

# 5. Phone home: SSH is ready, serveme can push config files
if [ -n "$CALLBACK_URL" ]; then
    echo "SSH ready, phoning home..."
    for attempt in 1 2 3; do
        if curl -sf --connect-timeout 5 --max-time 10 -X POST "$CALLBACK_URL" \
            -H "X-Callback-Token: ${CALLBACK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"status\":\"ssh_ready\"}"; then
            echo "SSH ready callback successful"
            break
        else
            echo "SSH ready callback attempt $attempt failed, retrying in 5s..."
            sleep 5
        fi
    done
fi

# 6. Wait for reservation.cfg to be pushed by serveme (max 5 minutes)
RESERVATION_CFG="$HOME/hlserver/tf2/tf/cfg/reservation.cfg"
echo "Waiting for reservation.cfg..."
for i in $(seq 1 300); do
    if [ -f "$RESERVATION_CFG" ]; then
        echo "reservation.cfg found, starting TF2 server"
        break
    fi
    sleep 1
done
if [ ! -f "$RESERVATION_CFG" ]; then
    echo "Warning: reservation.cfg not found after 5 minutes, starting anyway"
fi

# 7. Refresh map list from serveme API (fall back to baked-in list)
MAPLIST_PATH="$HOME/hlserver/tf2/tf/cfg/maplist_full.txt"
MAPLIST_URL="${MAPLIST_URL:-https://direct.serveme.tf/api/maps.txt}"
echo "Refreshing map list from $MAPLIST_URL..."
if curl -sf --connect-timeout 5 --max-time 15 "$MAPLIST_URL" -o "${MAPLIST_PATH}.tmp" && [ -s "${MAPLIST_PATH}.tmp" ]; then
    mv "${MAPLIST_PATH}.tmp" "$MAPLIST_PATH"
    echo "Map list updated: $(wc -l < "$MAPLIST_PATH") maps"
else
    rm -f "${MAPLIST_PATH}.tmp"
    echo "Could not refresh map list, keeping baked-in version"
fi

# 8. Read first map from file (written by serveme) or fall back to env/default
FIRST_MAP_FILE="$HOME/hlserver/tf2/tf/cfg/first_map.txt"
if [ -f "$FIRST_MAP_FILE" ]; then
    FIRST_MAP="$(cat "$FIRST_MAP_FILE")"
    echo "Using first map from file: $FIRST_MAP"
fi
FIRST_MAP="${FIRST_MAP:-ctf_turbine}"

# 9. Download first map if not already present
MAP_PATH="$HOME/hlserver/tf2/tf/maps/${FIRST_MAP}.bsp"
if [ ! -f "$MAP_PATH" ]; then
    echo "Downloading map: $FIRST_MAP"
    wget -nv "https://fastdl.serveme.tf/maps/${FIRST_MAP}.bsp" -O "$MAP_PATH" || \
    wget -nv "http://fakkelbrigade.eu/maps/${FIRST_MAP}.bsp" -O "$MAP_PATH" || \
    echo "Warning: Could not download $FIRST_MAP"
fi

# 10. Start TF2 server in background
# Disable set -e: from here on we need signal traps to work reliably
set +e
PORT="${PORT:-27015}"
cd "$HOME/hlserver"
TV_PORT="${TV_PORT:-$((PORT + 5))}"
CLIENT_PORT="${CLIENT_PORT:-40001}"
STEAM_PORT="${STEAM_PORT:-30001}"
FAKEIP_FLAG="${ENABLE_FAKEIP:+-enablefakeip}"

# Graceful shutdown: flush logs, stop STV, then exit.
# The container runtime will clean up child processes after we exit.
graceful_shutdown() {
    echo "Received shutdown signal, stopping STV recording..."
    if [ -x "$HOME/hlserver/rcon" ]; then
        RCON_CMD="$HOME/hlserver/rcon -H 127.0.0.1 -p $PORT -P ${RCON_PASSWORD:-changeme}"
        $RCON_CMD tv_stoprecord 2>/dev/null || true
        $RCON_CMD sv_logflush 1 2>/dev/null || true
        sleep 2
    fi
    echo "Shutdown complete, exiting."
    exit 0
}
trap graceful_shutdown TERM INT

tf2/srcds_run -game tf -ip 0.0.0.0 -port "$PORT" $FAKEIP_FLAG \
    +clientport "$CLIENT_PORT" -steamport "$STEAM_PORT" \
    +map "$FIRST_MAP" +tv_port "$TV_PORT" +tv_maxclients 32 +tv_enable 1 \
    "$@" &
SRCDS_PID=$!

# 11. Wait for RCON TCP port to be open, then phone home: TF2 is ready
if [ -n "$CALLBACK_URL" ]; then
    echo "Waiting for TF2 to start on port $PORT..."
    for i in $(seq 1 120); do
        if ss -tln | grep -q ":${PORT}[[:space:]]"; then
            echo "TF2 is listening, phoning home..."
            for attempt in 1 2 3; do
                if curl -sf --connect-timeout 5 --max-time 10 -X POST "$CALLBACK_URL" \
                    -H "X-Callback-Token: ${CALLBACK_TOKEN}" \
                    -H "Content-Type: application/json" \
                    -d "{\"status\":\"tf2_ready\",\"port\":\"$PORT\"}"; then
                    echo "TF2 ready callback successful"
                    break
                else
                    echo "TF2 ready callback attempt $attempt failed, retrying in 5s..."
                    sleep 5
                fi
            done
            break
        fi
        sleep 1
    done
fi

# 12. Wait on srcds process
wait $SRCDS_PID
