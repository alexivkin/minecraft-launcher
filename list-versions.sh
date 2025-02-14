#!/bin/bash

# get the latest version and build the latest
set -euo pipefail

MAINLINE_VERSIONS_JSON="https://launchermeta.mojang.com/mc/game/version_manifest.json"
FORGE_VERSIONS_JSON=http://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json
NEOFORGE_VERSIONS_JSON=https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge

MAINLINE_VERSIONS=$(curl -s $MAINLINE_VERSIONS_JSON | jq -r '.versions[]|select(.type == "release").id' | sort -u --version-sort | sed -z 's/\n/, /g;s/, $//' )
FORGE_SUPPORTED_VERSIONS=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos| keys[] | rtrimstr("-latest") | rtrimstr("-recommended")' | sort -u --version-sort | sed -z 's/\n/-forge, /g' | sed 's/, $//')
NEOFORGE_SUPPORTED_VERSIONS=$(curl -fsSL $NEOFORGE_VERSIONS_JSON | jq -r '.versions[]' | sed -r 's/([0-9]+\.[0-9]+).*/\1/;s/^/1./' | sort -Vu | sed -z 's/\n/-neoforge, /g' | sed 's/, $//')

echo -e "Mainline versions: $MAINLINE_VERSIONS\n"
echo -e "Forge versions: $FORGE_SUPPORTED_VERSIONS\n"
echo -e "NeoForge versions: $NEOFORGE_SUPPORTED_VERSIONS\n"
