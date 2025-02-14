#!/bin/bash

# get the latest version and build the latest
#set -x
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo Specify the Minecraft Server Version or "latest" for the latest version of the minecraft server to get the compatible neoforge for
    exit 0
fi

MAINLINE_VERSIONS_JSON=https://launchermeta.mojang.com/mc/game/version_manifest.json
NEOFORGE_VERSIONS_JSON=https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge

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

version_slug=$(echo $MAINLINE_VERSION | cut -d . -f 2)

if [[ ! -x $(command -v javac) ]]; then
    echo "Installing neoforge requires a java compiler."
    if [[ $version_slug -le 16 ]]; then
        echo "Java 8 is required to run older versions of minecraft. Run: sudo apt install openjdk-8-jdk"
    elif [[ $version_slug -le 17 ]]; then
        echo "1.17 JDK is recommended. Run: sudo apt install openjdk-17-jdk"
    else
        echo "1.21+ JDK is recommended.. Run: sudo apt install openjdk-21-jdk"
    fi
    exit 3
fi

NEOFORGE_VERSION=$(curl -fsSL $NEOFORGE_VERSIONS_JSON | jq -r '.versions[]' | { grep "${MAINLINE_VERSION:2}" || true; } | sort --version-sort | tail -1)
if [[ -z $NEOFORGE_VERSION ]]; then
    NEOFORGE_SUPPORTED_VERSIONS=$(curl -fsSL $NEOFORGE_VERSIONS_JSON | jq -r '.versions[]' | sed -r 's/([0-9]+\.[0-9]+).*/\1/;s/^/1./' | sort -Vu | sed -z 's/\n/, /g')
    echo -e "ERROR: Version $MAINLINE_VERSION is not supported by NeoForge. Supported versions are:\n$NEOFORGE_SUPPORTED_VERSIONS"
    exit 2
fi

# get mainline if we don't already have it
if [[ ! -f versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config ]]; then
    ./get-minecraft-client.sh $MAINLINE_VERSION
fi

echo "Downloading NeoForge version $1..."

#NeoForgeVersion=$MAINLINE_VERSION-$NEOFORGE_VERSION
numNeoForgeVersion=${NEOFORGE_VERSION//./} # a decimal number for comparisons

VERSION_DIR="versions/$MAINLINE_VERSION-neoforge"
mkdir -p $VERSION_DIR

# for versions 27 and onward (minecraft 1.14) download the installer
NEOFORGE_INSTALLER="neoforge-$NEOFORGE_VERSION-installer.jar"
if [[ ! -f $VERSION_DIR/$NEOFORGE_INSTALLER ]]; then
    echo "Downloading $NEOFORGE_VERSION installer"
    downloadUrl=https://maven.neoforged.net/releases/net/neoforged/neoforge/$NEOFORGE_VERSION/$NEOFORGE_INSTALLER
    #echo "$downloadUrl"
    if ! curl -o $VERSION_DIR/$NEOFORGE_INSTALLER -fsSL $downloadUrl; then
        echo no url worked
        exit 3
    fi
else
	echo "NeoForge installer $NEOFORGE_INSTALLER is already downloaded"
fi

lib_base="$VERSION_DIR/libraries"

# stuff into a var for later use
VERSION_DETAILS=$(unzip -qc $VERSION_DIR/$NEOFORGE_INSTALLER version.json)
# run the installer from a stub allowing the CLI use
pushd $VERSION_DIR > /dev/null
echo "{}" > launcher_profiles.json
echo "{}" > launcher_profiles_microsoft_store.json # needed since v36
installerver=36
echo "Compiling the client installer..."
javac -cp $NEOFORGE_INSTALLER ../../ClientInstaller$installerver.java -d .
echo "Running the installer..."
if ! java -cp $NEOFORGE_INSTALLER:. ClientInstaller$installerver > neoforge-installer.log ; then
    echo "NeoForge client installation failed. Check $VERSION_DIR/neoforge-installer.log"
    exit 1
fi
# cleanup
rm ClientInstaller$installerver.class
rm launcher_profiles.json
rm launcher_profiles_microsoft_store.json
rm -rf versions # remove to avoid confusion. but keep the installer libraries around in case we need to reinstall
popd > /dev/null
NEOFORGE_CP=""

echo "$VERSION_DETAILS" > $VERSION_DIR/$MAINLINE_VERSION-neoforge-$NEOFORGE_VERSION.json

echo "Downloading the libraries for NeoForge $NEOFORGE_VERSION ..."

for name in $(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.clientreq or .clientreq == null) | .name'); do
    # split the name up
    s=(${name//:/ })
    class=${s[0]}
    lib=${s[1]}
    ver=${s[2]}
    # get destination path
    full_path=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'")' | jq -r --slurp 'first | .downloads.artifact.path') # slurp to get the first match
    if [[ $full_path != "null" ]]; then
        file=$(basename $full_path)
        path=$(dirname $full_path)
    else
        file="$lib-$ver.jar"
        path="${class//./\/}/$lib/$ver"
    fi
    # get source url
    url=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'")' | jq -r --slurp 'first | .downloads.artifact.url')
    if [[ $url == "null" ]]; then
        baseurl=$(echo $VERSION_DETAILS | jq -r '.libraries[] | select(.name=="'$name'")' | jq -r --slurp 'first | .url')
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
                echo "can't download"
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
    #NEOFORGE_CP="${NEOFORGE_CP}$dest:"
    # use relative library path
    if ! echo "$NEOFORGE_CP" | grep -q "libraries/$path/$file:" ; then # only add if it's not already in the path to avoid duplicates
    	NEOFORGE_CP="${NEOFORGE_CP}libraries/$path/$file:"
    fi
done

MAINLINE_CLIENT_JAR="versions/$MAINLINE_VERSION/$MAINLINE_VERSION.jar"
# add NeoForge specific tweaks
MAIN_JAR=$(echo $VERSION_DETAILS | jq -r '.mainClass')

# Clone mainline config parts to neoforge.
# Not using the "source" command because it will try to expand vars built into JVM_OPTS
JAVA=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/JAVA="\(.*\)"/\1/p')
# rework the path so it points at the mainline right folder
CP=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/classpath="\(.*\)"/\1/p' | sed -n "s|libraries/|../$MAINLINE_VERSION/libraries/|gp" | sed -n "s|$MAINLINE_VERSION.jar|../$MAINLINE_VERSION/$MAINLINE_VERSION.jar|p" )

LOG_CONFIG=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/log_path="\(.*\)"/\1/p')
if [[ ! -f $VERSION_DIR/$LOG_CONFIG ]]; then
    cp versions/$MAINLINE_VERSION/$LOG_CONFIG $VERSION_DIR/$LOG_CONFIG
fi

ASSET_INDEX=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.json | jq -r '.assetIndex.id')
#GAME_ARGS="$GAME_ARGS --tweakClass net.minecraftneoforge.fml.common.launcher.FMLTweaker --versionType NeoForge"

# Build minecraft args from arglist if minecraftArguments string is absent
GAME_ARGS=$(echo $VERSION_DETAILS | jq -r '.minecraftArguments')
if [[ $GAME_ARGS == "null" ]]; then
     # collect from game arguments
    MAINLINE_GAME_ARGS=$(cat versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config | sed -n 's/GAME_ARGS="\(.*\)"/\1/p')
    GAME_ARGS="$MAINLINE_GAME_ARGS $(echo $VERSION_DETAILS | jq -r '[.arguments.game[] | strings] | join(" ")')"
fi

if [[ $(echo $VERSION_DETAILS | jq -r '.arguments.jvm') != "null" ]]; then
    NEOFORGE_JVM_OPTS=$(echo $VERSION_DETAILS | jq -r  '[.arguments.jvm[] | strings] | join(" ")') # present on NeoForge 39+
else
    NEOFORGE_JVM_OPTS=""
fi

JVM_OPTS=$NEOFORGE_JVM_OPTS' -Xss1M -Djava.library.path=${natives_directory} -Dminecraft.launcher.brand=${launcher_name} -Dminecraft.launcher.version=${launcher_version} -Dlog4j.configurationFile=${log_path} -cp ${classpath}'

#LOG_FILE=$(echo $VERSION_DETAILS | jq -r '.logging.client.file.id')

CONFIG_FILE="$VERSION_DIR/$MAINLINE_VERSION-neoforge.config"

echo "Creating bash config file $CONFIG_FILE"
cat > $CONFIG_FILE << EOC
# Minecraft $MAINLINE_VERSION-neoforge
VER="$$NEOFORGE_VERSION"
# static variables
assets_root="../../assets" # assets are shared across all versions
auth_uuid=00000000-0000-0000-0000-000000000000
auth_access_token=0
clientid=0
auth_xuid=0
version_type=release
user_type=legacy
launcher_name="minecraft-launcher"
launcher_version="2.1.1349"
# dynamic variables
# paths are relative to $VERSION_DIR
MAIN="$MAIN_JAR"
assets_index_name="$ASSET_INDEX"
natives_directory="../$MAINLINE_VERSION/$MAINLINE_VERSION-natives"
log_path="$LOG_CONFIG"
classpath="${NEOFORGE_CP}${CP}"
# NeoForge specific variables used in NEOFORGE_JVM_OPTS
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
