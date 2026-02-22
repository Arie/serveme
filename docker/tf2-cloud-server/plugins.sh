#!/bin/bash
set -e

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

# tf2rue (TFTrue replacement, zip contents are relative to addons/sourcemod/)
cd "$HOME/hlserver/tf2/tf/addons/sourcemod"
wget -nv "https://github.com/sapphonie/tf2rue/releases/latest/download/tf2rue.zip" -O "tf2rue.zip"
unzip -o tf2rue.zip
rm tf2rue.zip

# Re-add funcommands.smx and funvotes.smx (removed by upstream sourcemod.sh)
cd /tmp
sm_url=$(wget -q -O - "http://www.sourcemod.net/downloads.php?branch=stable" | grep -oP -m1 "https://[a-z.]+/smdrop/[0-9.]+/sourcemod-(.*)-linux.tar.gz")
wget -nv "$sm_url" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz addons/sourcemod/plugins/funcommands.smx addons/sourcemod/plugins/funvotes.smx
cp addons/sourcemod/plugins/funcommands.smx addons/sourcemod/plugins/funvotes.smx \
    "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins/"
rm -rf addons sourcemod.tar.gz

# Remove whitelisttf.smx (conflicts with tf2rue which replaces its functionality)
rm -f "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins/whitelisttf.smx"

chmod 0664 "$HOME/hlserver/tf2/tf/addons/sourcemod/plugins"/*.smx
