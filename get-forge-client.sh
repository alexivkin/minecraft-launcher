#!/bin/bash

# get the latest version and build the latest

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo Specify the Minecraft Server Version or "latest" for the latest version of the minecraft server to get the compatible forge for
    exit 0
fi

echo "Downloading Forge version $1..."

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

#FORGE_VERSION=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r ".promos[\"$MAINLINE_VERSION-recommended\"]")
#if [[ $FORGE_VERSION == "null" ]]; then
    FORGE_VERSION=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r ".promos[\"$MAINLINE_VERSION-latest\"]")
    if [[ $FORGE_VERSION == "null" ]]; then
        FORGE_SUPPORTED_VERSIONS=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos| keys[] | rtrimstr("-latest") | rtrimstr("-recommended")' | sort -u)
        echo "ERROR: Version $MAINLINE_VERSION is not supported by Forge. Supported versions are $FORGE_SUPPORTED_VERSIONS"
        #curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos | keys[]' | sed -r 's/(-latest|-recommended)//' | sort -u
        exit 2
    fi
#fi

# get mainline if we don't already have it
if [[ ! -f versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config ]]; then
    ./get-minecraft-client.sh $MAINLINE_VERSION
fi

# temp bugfix workaround
if [[ $FORGE_VERSION == "27.0.24" ]]; then
    FORGE_VERSION="27.0.21"
fi

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

# for versions 27 and onward (minecraft 1.14) download the installer
if [[ ${FORGE_VERSION%%.*} -ge 27 ]]; then
    FORGE_INSTALLER="forge-$shortForgeVersion-installer.jar"
    if [[ ! -f $VERSION_DIR/$FORGE_INSTALLER ]]; then
        echo "Downloading $normForgeVersion installer"
        downloadUrl=http://files.minecraftforge.net/maven/net/minecraftforge/forge/$shortForgeVersion/forge-$shortForgeVersion-installer.jar
        #echo "$downloadUrl"
        if ! curl -o $VERSION_DIR/$FORGE_INSTALLER -fsSL $downloadUrl; then
            downloadUrl=http://files.minecraftforge.net/maven/net/minecraftforge/forge/$normForgeVersion/forge-$normForgeVersion-installer.jar
            echo "...trying $downloadUrl"
            if ! curl -o $VERSION_DIR/$FORGE_INSTALLER -fsSL $downloadUrl; then
                echo no url worked
                exit 3
            fi
        fi
    else
        echo "Forge installer $FORGE_INSTALLER is already downloaded"
    fi
fi

#if [[ ! -f "forge-$shortForgeVersion-universal.jar" ]]; then
#    echo "Extracting the forge jar $shortForgeVersion"
#    jar xvf $FORGE_UNIVERSAL forge-$shortForgeVersion-universal.jar
#fi

libdir="libraries"
echo "Getting the libs for $shortForgeVersion ..."

#rooturl="http://files.minecraftforge.net/maven" # from http://files.minecraftforge.net/mirror-brand.list

# version file moved into the installer after 1.12
#if [[  -f $VERSION_DIR/$FORGE_INSTALLER ]]; then
if [[ ${FORGE_VERSION%%.*} -ge 27 ]]; then
    VERSION_DETAILS=$(unzip -qc $VERSION_DIR/$FORGE_INSTALLER version.json)
else
    # stuff into a var for later use
    VERSION_DETAILS=$(unzip -qc $VERSION_DIR/$FORGE_UNIVERSAL version.json)
fi

echo $VERSION_DETAILS > $VERSION_DIR/$MAINLINE_VERSION-forge-$FORGE_VERSION.json

# get all the necessary libs for this forge server, starting with the forge itself
FORGE_CP="$VERSION_DIR/$FORGE_UNIVERSAL:"

for name in $(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.clientreq or .clientreq == null) | .name'); do
    # split the name up
    s=(${name//:/ })
    # and rebuild it
    class=${s[0]}
    lib=${s[1]}
    ver=${s[2]}
    file="$lib-$ver.jar"
    path="${class//./\/}/$lib/$ver"
    # ignore the forge jar entry as we are keeping it in a different folder, and already added to FORGE_CP
    if [[ $class == "net.minecraftforge" && $lib == "forge" ]]; then
        continue
    fi
    baseurl=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'") | .url')
    if [[ $baseurl == "null" ]]; then
        baseurl="https://libraries.minecraft.net/"
    fi
    mkdir -p "$libdir/$path"
    dest="$libdir/$path/$file"
    if [[ ! -f $dest ]]; then
        echo "$baseurl$path/$file"
        if ! curl -fsSL -o $dest "$baseurl$path/$file"; then
            # get and unpack augmented pack200 file
            echo "...trying $baseurl$path/$file.pack.xz"
            if ! curl -fsSL -o $dest.pack.xz "$baseurl$path/$file.pack.xz"; then
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

MAINLINE_CLIENT_JAR="versions/$MAINLINE_VERSION/$MAINLINE_VERSION.jar"
# add Forge specific tweaks
MAIN_JAR=$(echo $VERSION_DETAILS | jq -r '.mainClass')

# Clone mainline config parts to forge.
# Not using the "source" command because it will try to expand vars built into JVM_OPTS
JAVA=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/JAVA="\(.*\)"/\1/p')
CP=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/classpath="\(.*\)"/\1/p')
LOG_CONFIG=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/log_path="\(.*\)"/\1/p')

GAME_ARGS=$(echo $VERSION_DETAILS | jq -r '.minecraftArguments')

ASSET_INDEX=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.json | jq -r '.assetIndex.id')
#GAME_ARGS="$GAME_ARGS --tweakClass net.minecraftforge.fml.common.launcher.FMLTweaker --versionType Forge"

# Build minecraft args from arglist if minecraftArguments string is absent
GAME_ARGS=$(echo $VERSION_DETAILS | jq -r '.minecraftArguments')
if [[ $GAME_ARGS == "null" ]]; then
     # collect from game arguments
    GAME_ARGS=$(echo $VERSION_DETAILS | jq -r  '[.arguments.game[] | strings] | join(" ")')
fi

#LOG_FILE=$(echo $VERSION_DETAILS | jq -r '.logging.client.file.id')
JVM_OPTS='-Xss1M -Djava.library.path=${natives_directory} -Dminecraft.launcher.brand=${launcher_name} -Dminecraft.launcher.version=${launcher_version} -Dlog4j.configurationFile=${log_path} -cp ${classpath}'

CONFIG_FILE="$VERSION_DIR/$MAINLINE_VERSION-forge.config"

echo Creating bash config file $CONFIG_FILE
cat > $CONFIG_FILE << EOC
VER="$shortForgeVersion or $FORGE_VERSION"
MAIN="$MAIN_JAR"
assets_index_name="$ASSET_INDEX"
natives_directory="versions/$MAINLINE_VERSION/$MAINLINE_VERSION-natives"
log_path="$LOG_CONFIG"
#classpath="$VERSION_DIR/$FORGE_UNIVERSAL:${FORGE_CP}${CP}"
classpath="${FORGE_CP}${CP}"
# config lines
JAVA="$JAVA"
JVM_OPTS="$JVM_OPTS"
GAME_ARGS="$GAME_ARGS"
EOC
