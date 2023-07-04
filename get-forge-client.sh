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

FORGE_VERSION=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r ".promos[\"$MAINLINE_VERSION-latest\"]")
if [[ $FORGE_VERSION == "null" ]]; then
    FORGE_SUPPORTED_VERSIONS=$(curl -fsSL $FORGE_VERSIONS_JSON | jq -r '.promos| keys[] | rtrimstr("-latest") | rtrimstr("-recommended")' | sort -u --version-sort)
    echo -e "ERROR: Version $MAINLINE_VERSION is not supported by Forge. Supported versions are:\n$FORGE_SUPPORTED_VERSIONS"
    exit 2
fi

# get mainline if we don't already have it
if [[ ! -f versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config ]]; then
    ./get-minecraft-client.sh $MAINLINE_VERSION
fi

# temp bugfix workaround
#if [[ $FORGE_VERSION == "27.0.24" ]]; then
#    FORGE_VERSION="27.0.21"
#fi

normForgeVersion=$MAINLINE_VERSION-$FORGE_VERSION-$norm
shortForgeVersion=$MAINLINE_VERSION-$FORGE_VERSION
numForgeVersion=${FORGE_VERSION//./} # a decimal number for comparisons

FORGE_UNIVERSAL="forge-$shortForgeVersion-universal.jar"

VERSION_DIR="versions/$MAINLINE_VERSION-forge"
mkdir -p $VERSION_DIR

# for versions before 27 use the universal jar
if [[ ${FORGE_VERSION%%.*} -lt 27 ]]; then
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
else
    # for versions 27 and onward (minecraft 1.14) download the installer
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

lib_base="$VERSION_DIR/libraries"
echo "Getting the libs for $shortForgeVersion ..."

#rooturl="http://files.minecraftforge.net/maven" # from http://files.minecraftforge.net/mirror-brand.list

# version file moved into the installer after 1.12
#if [[  -f $VERSION_DIR/$FORGE_INSTALLER ]]; then
if [[ ${FORGE_VERSION%%.*} -ge 27 ]]; then
    # stuff into a var for later use
    VERSION_DETAILS=$(unzip -qc $VERSION_DIR/$FORGE_INSTALLER version.json)
    # run the installer from a stub allowing the CLI use
    pushd $VERSION_DIR > /dev/null
    echo "{}" > launcher_profiles.json
    echo "{}" > launcher_profiles_microsoft_store.json # needed since v36
    #if [[ ${FORGE_VERSION%%.*} -lt 36 ]]; then
    #    installerver=14
    #else
        installerver=36
    #fi
    echo "Compiling the client installer..."
    javac -cp $FORGE_INSTALLER ../../ClientInstaller$installerver.java -d .
    echo "Running the installer..."
    if ! java -cp $FORGE_INSTALLER:. ClientInstaller$installerver > forge-installer.log ; then
        echo "Forge client installation failed. Check forge-installer.log"
        exit 1
    fi
    # cleanup
    rm ClientInstaller$installerver.class
    rm launcher_profiles.json
    rm launcher_profiles_microsoft_store.json
    rm -rf versions # remove to avoid confusion. but keep the installer libraries around in case we need to reinstall
    popd > /dev/null
    if [[ ${FORGE_VERSION%%.*} -lt 39 ]]; then
        FORGE_CP="libraries/net/minecraftforge/forge/$shortForgeVersion/forge-$shortForgeVersion.jar:"
    else
        FORGE_CP="" # switched to modules
    fi
else
    VERSION_DETAILS=$(unzip -qc $VERSION_DIR/$FORGE_UNIVERSAL version.json)
    FORGE_CP="$FORGE_UNIVERSAL:"
fi

echo "$VERSION_DETAILS" > $VERSION_DIR/$MAINLINE_VERSION-forge-$FORGE_VERSION.json

# get all the necessary libs for this forge server, starting with the forge itself
#FORGE_CP="$VERSION_DIR/$FORGE_UNIVERSAL:"

for name in $(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.clientreq or .clientreq == null) | .name'); do
    # split the name up
    s=(${name//:/ })
    class=${s[0]}
    lib=${s[1]}
    ver=${s[2]}
    # ignore the forge jar entry as we are keeping it in a different folder, and already added to FORGE_CP
    if [[ $class == "net.minecraftforge" && $lib == "forge" ]]; then
        continue
    fi
    # get destination path
    full_path=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'") | .downloads.artifact.path')
    if [[ $full_path != "null" ]]; then
        file=$(basename $full_path)
        path=$(dirname $full_path)
    else
        file="$lib-$ver.jar"
        path="${class//./\/}/$lib/$ver"
    fi
    # get source url
    url=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'") | .downloads.artifact.url')
    if [[ $url == "null" ]]; then
        baseurl=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'") | .url')
        if [[ $baseurl == "null" ]]; then
            baseurl="https://libraries.minecraft.net/"
        fi
        url="$baseurl$path/$file"
    fi
    # create as needed
    mkdir -p "$lib_base/$path"
    dest="$lib_base/$path/$file"
    if [[ ! -f $dest ]]; then
        echo "$url"
        if ! curl -fsSL -o $dest "$url"; then
            # get and unpack augmented pack200 file
            echo "...trying $url.pack.xz"
            if ! curl -fsSL -o $dest.pack.xz "$url.pack.xz"; then
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
    #FORGE_CP="${FORGE_CP}$dest:"
    # use relative library path
    FORGE_CP="${FORGE_CP}libraries/$path/$file:"
done

MAINLINE_CLIENT_JAR="versions/$MAINLINE_VERSION/$MAINLINE_VERSION.jar"
# add Forge specific tweaks
MAIN_JAR=$(echo $VERSION_DETAILS | jq -r '.mainClass')

# Clone mainline config parts to forge.
# Not using the "source" command because it will try to expand vars built into JVM_OPTS
JAVA=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/JAVA="\(.*\)"/\1/p')
# rework the path so it points at the mainline right folder
CP=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/classpath="\(.*\)"/\1/p' | sed -n "s|libraries/|../$MAINLINE_VERSION/libraries/|gp" | sed -n "s|$MAINLINE_VERSION.jar|../$MAINLINE_VERSION/$MAINLINE_VERSION.jar|p" )

LOG_CONFIG=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/log_path="\(.*\)"/\1/p')
if [[ ! -f $VERSION_DIR/$LOG_CONFIG ]]; then
    cp versions/$MAINLINE_VERSION/$LOG_CONFIG $VERSION_DIR/$LOG_CONFIG
fi

ASSET_INDEX=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.json | jq -r '.assetIndex.id')
#GAME_ARGS="$GAME_ARGS --tweakClass net.minecraftforge.fml.common.launcher.FMLTweaker --versionType Forge"

# Build minecraft args from arglist if minecraftArguments string is absent
GAME_ARGS=$(echo $VERSION_DETAILS | jq -r '.minecraftArguments')
if [[ $GAME_ARGS == "null" ]]; then
     # collect from game arguments
    MAINLINE_GAME_ARGS=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/GAME_ARGS="\(.*\)"/\1/p')
    GAME_ARGS="$MAINLINE_GAME_ARGS $(echo $VERSION_DETAILS | jq -r '[.arguments.game[] | strings] | join(" ")')"
fi

if [[ $(echo $VERSION_DETAILS | jq -r '.arguments.jvm') != "null" ]]; then
    FORGE_JVM_OPTS=$(echo $VERSION_DETAILS | jq -r  '[.arguments.jvm[] | strings] | join(" ")') # present on Forge 39+
else
    FORGE_JVM_OPTS=""
fi

JVM_OPTS=$FORGE_JVM_OPTS' -Xss1M -Djava.library.path=${natives_directory} -Dminecraft.launcher.brand=${launcher_name} -Dminecraft.launcher.version=${launcher_version} -Dlog4j.configurationFile=${log_path} -cp ${classpath}'

#LOG_FILE=$(echo $VERSION_DETAILS | jq -r '.logging.client.file.id')

CONFIG_FILE="$VERSION_DIR/$MAINLINE_VERSION-forge.config"

echo "Creating bash config file $CONFIG_FILE"
cat > $CONFIG_FILE << EOC
# Minecraft $MAINLINE_VERSION-forge
VER="$shortForgeVersion aka $FORGE_VERSION"
# static variables
assets_root="../../assets" # assets are shared across all versions
auth_uuid=0
auth_access_token=0
clientid=0
auth_xuid=0
version_type=relase
user_type=legacy
launcher_name="minecraft-launcher"
launcher_version="2.1.1349"
# dynamic variables
# paths are relative to $VERSION_DIR
MAIN="$MAIN_JAR"
assets_index_name="$ASSET_INDEX"
natives_directory="../$MAINLINE_VERSION/$MAINLINE_VERSION-natives"
log_path="$LOG_CONFIG"
classpath="${FORGE_CP}${CP}"
# Forge specific variables used in FORGE_JVM_OPTS
# 10.13.4
user_properties="{}"
# 39.1.2+
classpath_separator=:
library_directory=libraries
version_name=$MAINLINE_VERSION
# config lines
JAVA="$JAVA"
JVM_OPTS="$JVM_OPTS"
GAME_ARGS="$GAME_ARGS"
EOC
