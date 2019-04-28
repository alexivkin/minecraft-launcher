#!/bin/bash

# get the latest version and build the latest

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo Specify the Minecraft Server Version or "latest" for the latest version of the minecraft server to get the compatible forge for
    exit 0
fi

MAINLINE_VERSIONS_JSON=https://launchermeta.mojang.com/mc/game/version_manifest.json
FORGE_VERSIONS_JSON=http://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json

if [[ $1 == "latest" ]]; then
    MAINLINE_VERSION=$(curl -fsSL $MAINLINE_VERSIONS_JSON | jq -r '.latest.release')
else
    MAINLINE_VERSION=$1
fi

norm=$MAINLINE_VERSION

case $MAINLINE_VERSION in
    *.*.*)
      norm=$MAINLINE_VERSION ;;
    *.*)
      norm=${MAINLINE_VERSION}.0 ;;
esac

FORGE_VERSION=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r ".promos[\"$MAINLINE_VERSION-recommended\"]")
if [[ $FORGE_VERSION == "null" ]]; then
    FORGE_VERSION=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r ".promos[\"$MAINLINE_VERSION-latest\"]")
    if [[ $FORGE_VERSION == "null" ]]; then
        FORGE_SUPPORTED_VERSIONS=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos| keys[] | rtrimstr("-latest") | rtrimstr("-recommended")' | sort -u)
        echo "ERROR: Version $MAINLINE_VERSION is not supported by Forge. Supported versions are $FORGE_SUPPORTED_VERSIONS"
        #curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos | keys[]' | sed -r 's/(-latest|-recommended)//' | sort -u
        exit 2
    fi
fi

./get-minecraft-client.sh $MAINLINE_VERSION

normForgeVersion=$MAINLINE_VERSION-$FORGE_VERSION-$norm
shortForgeVersion=$MAINLINE_VERSION-$FORGE_VERSION

FORGE_UNIVERSAL="forge-$shortForgeVersion-universal.jar"

VERSION_DIR="versions/$MAINLINE_VERSION-forge"
mkdir -p $VERSION_DIR

if [[ ! -f $VERSION_DIR/$FORGE_UNIVERSAL ]]; then
    echo "Downloading $normForgeVersion universal"
    downloadUrl=http://files.minecraftforge.net/maven/net/minecraftforge/forge/$shortForgeVersion/forge-$shortForgeVersion-universal.jar
    echo "$downloadUrl"
    if ! curl -o $VERSION_DIR/$FORGE_UNIVERSAL -fsSL $downloadUrl; then
        downloadUrl=http://files.minecraftforge.net/maven/net/minecraftforge/forge/$normForgeVersion/forge-$normForgeVersion-universal.jar
        echo "...trying $downloadUrl"
        if ! curl -o $VERSION_DIR/$FORGE_UNIVERSAL -fsSL $downloadUrl; then
            echo no url worked
            exit 3
        fi
    fi
fi

#if [[ ! -f "forge-$shortForgeVersion-universal.jar" ]]; then
#    echo "Extracting the forge jar $shortForgeVersion"
#    jar xvf $FORGE_UNIVERSAL forge-$shortForgeVersion-universal.jar
#fi

echo "Getting the libs for $shortForgeVersion ..."

libdir="libraries"

#rooturl="http://files.minecraftforge.net/maven" # from http://files.minecraftforge.net/mirror-brand.list

# stuff into a var for later use
VERSION_DETAILS=$(unzip -qc $VERSION_DIR/$FORGE_UNIVERSAL version.json)

echo $VERSION_DETAILS > $VERSION_DIR/$MAINLINE_VERSION-forge-$FORGE_VERSION.json

# get all the necessary libs for this forge server
FORGE_CP=""
for name in $(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.clientreq) | .name'); do
    # split the name up
    s=(${name//:/ })
    # and rebuild it
    class=${s[0]}
    lib=${s[1]}
    ver=${s[2]}
    file="$lib-$ver.jar"
    path="${class//./\/}/$lib/$ver"
    baseurl=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'") | .url')
    if [[ $baseurl == "null" ]]; then
        baseurl="https://libraries.minecraft.net"
    fi
    mkdir -p "$libdir/$path"
    dest="$libdir/$path/$file"
    if [[ ! -f $dest ]]; then
        echo "$baseurl/$path/$file"
        if ! curl -fsSL -o $dest "$baseurl/$path/$file"; then
            # get and unpack augmented pack200 file
            echo "...trying $baseurl/$path/$file.pack.xz"
            if ! curl -fsSL -o $dest.pack.xz "$baseurl/$path/$file.pack.xz"; then
                echo "cant download"
                exit 1
            fi
            xz -d $dest.pack.xz
            hexsiglen=$(xxd -s -8 -l 4 -e $dest.pack | cut -d ' ' -f 2)
            siglen=$(( 16#$hexsiglen ))
            fulllen=$(stat -c %s $dest.pack)
            croplen=$(( $fulllen-$siglen-8 ))
            dd if=$dest.pack of=$dest.pack.crop bs=$croplen count=1 2>/dev/null
            unpack200 $dest.pack.crop $dest
            rm $dest.pack.crop
            rm $dest.pack
        fi
    fi
    FORGE_CP="${FORGE_CP}$dest:"
done

MAIN_JAR=$(echo $VERSION_DETAILS | jq -r '.mainClass')

CONFIG_FILE="$VERSION_DIR/$MAINLINE_VERSION-forge.config"
echo Creating bash config file $CONFIG_FILE
cat > $CONFIG_FILE << EOC
VER=$shortForgeVersion or $FORGE_VERSION
MAIN="$MAIN_JAR"
assets_index_name=""
GAME_ARGS=$(echo $VERSION_DETAILS | jq -r '.minecraftArguments')
FORGE_CLASSPATH="${FORGE_CP}"
CLASSPATH="$CLASSPATH"
EOC

#rm $FORGE_UNIVERSAL
