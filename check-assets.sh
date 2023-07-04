#!/bin/bash
#
# Verify that the existings assets have correct checksums
# The installer curreently does this on the new version download
#
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo Specify the Minecraft Version
    exit 0
fi

VERSION_FILE="versions/$1/$1.json"

if [[ ! -f $VERSION_FILE ]]; then
    echo "The version $1 you indicated does not exist in as $VERSION_FILE. Make sure to download it first."
    exit 0
fi

ASSET_INDEX=$(jq -r '.assetIndex.id' $VERSION_FILE)
if [[ $ASSET_INDEX == "null" ]]; then
    echo "The version file $VERSION_FILE is missing the asset index."
    exit 0
fi
ASSET_INDEX_FILE="assets/indexes/$ASSET_INDEX.json"
ASSET_INDEX_SHA1=$(jq -r '.assetIndex.sha1' $VERSION_FILE)
ASSET_INDEX_SHA1CHECK=$(sha1sum $ASSET_INDEX_FILE | cut -d ' ' -f 1)
if [[ $ASSET_INDEX_SHA1 != $ASSET_INDEX_SHA1CHECK ]]; then
    echo "$ASSET_INDEX_FILE checksum is wrong. Remove and re-run."
    exit 1
fi

# check asset objects
OBJ_SERVER="https://resources.download.minecraft.net"
OBJ_FOLDER="assets/objects"
echo -n "Checking objects ..."
for objhash in $(cat $ASSET_INDEX_FILE | jq -rc '.objects[] | .hash'); do
    id=${objhash:0:2}
    objfile=$OBJ_FOLDER/$id/$objhash
    if [[ ! -f $objfile ]]; then
        echo "File $objfile is missing"
    else
        echo -n "."
        sha1check=$(sha1sum $objfile | cut -d ' ' -f 1)
        if [[ $objhash != $sha1check ]]; then
            echo "$objfile checksum is wrong. Remove and re-run."
        fi
    fi
done
echo "done"
