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

# MGE Mod (zip contents are relative to tf/)
cd "$HOME/hlserver/tf2/tf"
wget -nv "https://github.com/sapphonie/MGEMod/releases/latest/download/mge.zip" -O "mge.zip"
unzip -o mge.zip
rm mge.zip


# Better MGE spawns
cd "$HOME/hlserver/tf2/tf"
wget -nv "https://raw.githubusercontent.com/Arie/serveme/master/doc/mgemod_spawns.cfg" -O "addons/sourcemod/configs/mgemod_spawns.cfg"

# tf2rue (TFTrue replacement, zip contents are relative to addons/sourcemod/)
cd "$HOME/hlserver/tf2/tf/addons/sourcemod"
wget -nv "https://github.com/sapphonie/tf2rue/releases/latest/download/tf2rue.zip" -O "tf2rue.zip"
unzip -o tf2rue.zip
rm tf2rue.zip

# Remove whitelisttf.smx (conflicts with tf2rue which replaces its functionality)
rm -f "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins/whitelisttf.smx"

chmod 0664 "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins"/*.smx
