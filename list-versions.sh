#!/bin/bash

# get the latest version and build the latest
set -euo pipefail

MAINLINE_VERSIONS_JSON="https://launchermeta.mojang.com/mc/game/version_manifest.json"
FORGE_VERSIONS_JSON=http://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json

MAINLINE_VERSIONS=$(curl -s $MAINLINE_VERSIONS_JSON | jq -r '.versions[]|select(.type == "release").id' | sort -u --version-sort | sed -z 's/\n/, /g')
FORGE_SUPPORTED_VERSIONS=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos| keys[] | rtrimstr("-latest") | rtrimstr("-recommended")' | sort -u --version-sort | sed -z 's/\n/-forge, /g')

echo -e "Mainline versions: $MAINLINE_VERSIONS\n"
echo -e "Supported Forge versions: $FORGE_SUPPORTED_VERSIONS\n"
