#!/bin/bash

# get the latest version and build the latest

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo Specify the Minecraft Version or "latest" for the latest version of minecraft
    exit 0
fi

MAINLINE_VERSIONS_JSON=https://launchermeta.mojang.com/mc/game/version_manifest.json

# could also do latest.snapshot
if [[ $1 == "latest" ]]; then
    MAINLINE_VERSION=$(curl -fsSL $MAINLINE_VERSIONS_JSON | jq -r '.latest.release')
else
    MAINLINE_VERSION=$1
fi

MAINLINE_CLIENT_JAR="versions/$MAINLINE_VERSION/$MAINLINE_VERSION.jar"

VERSION_JSON=$(curl -s $MAINLINE_VERSIONS_JSON | jq --arg VERSION "$MAINLINE_VERSION" -r '[.versions[]|select(.id == $VERSION)][0].url')
if [[ $VERSION_JSON == "null" ]]; then
    echo "No mainline version $MAINLINE_VERSION exists. Available versions are"
    curl -s $MAINLINE_VERSIONS_JSON | jq -r '.versions[]|select(.type == "release").id'
    exit 1
fi

VERSION_DETAILS=$(curl -s $VERSION_JSON)
mkdir -p versions/$MAINLINE_VERSION
echo $VERSION_DETAILS > "versions/$MAINLINE_VERSION/$MAINLINE_VERSION.json"

# get the standard
if [[ ! -f $MAINLINE_CLIENT_JAR ]]; then
    echo -n "Downloading minecraft $MAINLINE_CLIENT_JAR ..."
    curl -sSL -o $MAINLINE_CLIENT_JAR $(echo $VERSION_DETAILS | jq -r '.downloads.client.url')
    echo "done"
fi

ASSET_INDEX=$(echo $VERSION_DETAILS | jq -r '.assetIndex.id')
if [[ ! $ASSET_INDEX == "null" ]]; then
    ASSET_INDEX_FILE="assets/indexes/$ASSET_INDEX.json"
    if [[ ! -f $ASSET_INDEX_FILE ]]; then
        echo -n "Downloading $ASSET_INDEX_FILE ..."
        mkdir -p assets/indexes
        curl -sSL -o $ASSET_INDEX_FILE $(echo $VERSION_DETAILS | jq -r '.assetIndex.url')
        echo "done"
    fi
fi

LOG_FILE=$(echo $VERSION_DETAILS | jq -r '.logging.client.file.id')
if [[ ! $LOG_FILE == "null" ]]; then
    LOG_CONFIG="assets/log_configs/$LOG_FILE"
    if [[ ! -f $LOG_CONFIG ]]; then
        echo -n "Downloading $LOG_CONFIG ..."
        mkdir -p assets/log_configs
        curl -sSL -o $LOG_CONFIG $(echo $VERSION_DETAILS | jq -r '.logging.client.file.url')
        echo "done"
    fi
fi

# get all the necessary libs for this client
for lib in $(echo $VERSION_DETAILS | jq -rc '.libraries[]'); do
    #echo $lib
    lib_name="libraries/"$(echo $lib | jq -r '.downloads.artifact.path')
    lib_path=$(dirname $lib_name)
    lib_url=$(echo $lib | jq -r '.downloads.artifact.url')
    if [[ ! $lib_name == "libraries/null" && ! -f $lib_name ]]; then
        allowed=true    # default if no rules are defined
        # check the rules for Linux
        rules=$(echo $lib | jq -rc '.rules')
        if [[ ! $rules == "null" ]]; then
            allowed=false
            for rule in $(echo $lib | jq -rc '.rules[]'); do
                if [[ $(echo $rule | jq -r '.os.name') == "linux" ]]; then
                    allowed=true
                    break
                fi
            done
            if [[ $allowed == "false" ]]; then
                #echo "$lib_name is not for linux"
                continue
            fi
        fi
        echo -n "Downloading $lib_name ..."
        mkdir -p $lib_path
        curl -sSL -o $lib_name $lib_url
        echo "done"
    fi
    native_linux=$(echo $lib | jq -rc '.natives.linux')
    if [[ ! $native_linux == "null" ]]; then
        native_linux_name="libraries/"$(echo $lib | jq -rc '.downloads.classifiers["'$native_linux'"].path')
        native_linux_path=$(dirname $native_linux_name)
        native_linux_url=$(echo $lib | jq -rc '.downloads.classifiers["'$native_linux'"].url')
        if [[ ! -f $native_linux_name ]]; then
            echo -n "Downloading $native_linux_name native linux library ..."
            mkdir -p $native_linux_path
            curl -sSL -o $native_linux_name $native_linux_url
            echo "done"
        fi
        native_so_path="versions/$MAINLINE_VERSION/$MAINLINE_VERSION-natives"
        # unpack natives even if the source jar has been downloaded, because natives are version specific
        echo -n "Unpacking to $native_linux_name to $native_so_path..."
        mkdir -p $native_so_path
        unzip -qn $native_linux_name -d $native_so_path # -n to never overwrite, -o to always
        echo "done"
    fi
done

# get asset objects
OBJ_SERVER="http://resources.download.minecraft.net"
OBJ_FOLDER="assets/objects"
echo -n "Downloading objects ..."
for objhash in $(cat $ASSET_INDEX_FILE | jq -rc '.objects[] | .hash'); do
    id=${objhash:0:2}
    objfile=$OBJ_FOLDER/$id/$objhash
    if [[ ! -f $objfile ]]; then
        echo -n "."
        mkdir -p "$OBJ_FOLDER/$id"
        curl -sSL -o $objfile $OBJ_SERVER/$id/$objhash
    fi
done
echo "done"

# build classpath. This will get even the OSX libs, but since they should not be downloaded we dont care
CP=$(echo $VERSION_DETAILS | jq -r '.libraries[]|"libraries/"+.downloads.artifact.path' | tr '\n' ':')
MAIN_JAR=$(echo $VERSION_DETAILS | jq -r '.mainClass')

# Build minecraft args from arglist if minecraftArguments string is absent
GAME_ARGS=$(echo $VERSION_DETAILS | jq -r '.minecraftArguments')
if [[ $GAME_ARGS == "null" ]]; then
     # collect from game arguments
    GAME_ARGS=$(echo $VERSION_DETAILS | jq -r  '[.arguments.game[] | strings] | join(" ")')
fi

# in latest minecraft this should come from
# from jvm option matching arch x86 (i.e. -Xss1M)
# and from .logging.client.argument
JVM_OPTS='-Xss1M -Djava.library.path=${natives_directory} -Dminecraft.launcher.brand=${launcher_name} -Dminecraft.launcher.version=${launcher_version} -Dlog4j.configurationFile=${log_path} -cp ${classpath}'

CONFIG_FILE="versions/$MAINLINE_VERSION/$MAINLINE_VERSION.config"

echo Creating bash config file $CONFIG_FILE
cat > $CONFIG_FILE << EOC
VER="$MAINLINE_VERSION"
MAIN="$MAIN_JAR"
assets_index_name="$ASSET_INDEX"
natives_directory="versions/$MAINLINE_VERSION/$MAINLINE_VERSION-natives"
log_path="$LOG_CONFIG"
classpath="${CP}$MAINLINE_CLIENT_JAR"
# config lines
JVM_OPTS="$JVM_OPTS"
GAME_ARGS="$GAME_ARGS"
EOC
