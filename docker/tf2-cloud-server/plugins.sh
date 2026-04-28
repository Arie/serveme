#!/bin/bash
set -e

# WebRCON
cd "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins"
wget -nv "https://github.com/Arie/serveme/raw/refs/heads/master/doc/web_rcon.smx" -O "web_rcon.smx"

# STAC anti-cheat (zip contents are relative to addons/sourcemod/)
cd "$HOME/hlserver/tf2/tf/addons/sourcemod"
wget -nv "https://github.com/sapphonie/StAC-tf2/releases/latest/download/stac.zip" -O "stac.zip"
unzip -o stac.zip
rm stac.zip

# RIPext (required by MGEMod auto cfg downloader)
cd "$HOME/hlserver/tf2/tf"
wget -nv "https://github.com/ErikMinekus/sm-ripext/releases/download/1.3.2/sm-ripext-1.3.2-linux.zip" -O "ripext.zip"
unzip -o ripext.zip
rm ripext.zip

# MGE Mod (zip contents are relative to tf/)
cd "$HOME/hlserver/tf2/tf"
wget -nv "https://github.com/mgetf/MGEMod/releases/latest/download/mge.zip" -O "mge.zip"
unzip -o mge.zip
rm mge.zip

cd "$HOME/hlserver/tf2/tf/addons/sourcemod"
wget -nv "https://github.com/mgetf/mge-config-downloader/releases/latest/download/mge_config_downloader.zip" -O "mge_config_downloader.zip"
unzip -o mge_config_downloader.zip
rm mge_config_downloader.zip


# tf2rue (TFTrue replacement, zip contents are relative to addons/sourcemod/)
cd "$HOME/hlserver/tf2/tf/addons/sourcemod"
wget -nv "https://github.com/sapphonie/tf2rue/releases/latest/download/tf2rue.zip" -O "tf2rue.zip"
unzip -o tf2rue.zip
rm tf2rue.zip

# Remove whitelisttf.smx (conflicts with tf2rue which replaces its functionality)
rm -f "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins/whitelisttf.smx"

# Accelerator crash reporter (upstream build from limetech)
cd "$HOME/hlserver/tf2/tf"
wget -nv "https://builds.limetech.io/files/accelerator-2.6.0-git165-dcf3449-linux.zip" -O "accelerator.zip"
unzip -o accelerator.zip -d /tmp/accel
cp -r /tmp/accel/linux/addons/. "$HOME/hlserver/tf2/tf/addons/"
rm -rf /tmp/accel accelerator.zip

chmod 0664 "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins"/*.smx

# Set MinidumpAccount for Accelerator crash reporting (steamID64 of ariekanarie)
CORE_CFG="$HOME/hlserver/tf2/tf/addons/sourcemod/configs/core.cfg"
if ! grep -q 'MinidumpAccount' "$CORE_CFG"; then
    # Replace the final closing `}` with MinidumpAccount entry + }
    sed -i '$d' "$CORE_CFG"
    printf '\t"MinidumpAccount"\t"76561197960497430"\n}\n' >> "$CORE_CFG"
fi
