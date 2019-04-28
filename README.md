# A custom Mincraft launcher written in Bash

Downloads and installs Minecraft version on demand, including all the appropriate libraries. Supports normal and Forge versions.

* Prerequisites - `jq`,`unzip`,`curl`

* Running

        ./start nick version

## How to replicate it manually

* Run the java launcher
* Login and start from the launcher. It will download all the new files for the new version.
** Alternatively grab https://launchermeta.mojang.com/mc/game/version_manifest.json
* Copy the natives. Grep for the path `ps -ef | grep java.library.path` then copy that folder `cp -a /tmp/folder $HOME/.minecraft/versions/$ver/$ver-natives`
** Alternatively natives can be found at https://libraries.minecraft.net/
* Copy-paste the whole -cp argument, along with the java args to a run script
** Runs script plus assets, libraries, and version folder it what you need to run minecraft

[Minecraft files](https://wiki.vg/Game_files)
