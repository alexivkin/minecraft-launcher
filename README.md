# A custom Mincraft launcher in Bash

A fully command line, better, easier way of managing multiple mincraft installations. Pairs well with the [minecraft server launcher for Linux](https://github.com/alexivkin/minecraft-server-container).
Downloads and installs Minecraft version on demand, including all the appropriate libraries. Supports normal(vanilla) and *Forge* versions. The versions and player profiles are kept in separate folders so you can have many versions and players at the same time. 


* Prerequisites - `jq`,`unzip`,`curl`. 
* Running - `./start <version> <player_nick>`
* To run a Forge version add a suffix "-forge" to the version. For example `./start 1.17.10-forge player1`. 
* If you want to see what normal and Forge versions are available run the script with a non-existing version, like this `./start 0 player1`, `./start 0-forge player1`

## How to add it to the KDE desktop 

To get the minecraft icon and the desktop link clone [this repo](https://aur.archlinux.org/minecraft-launcher.git), To install the icon run

`sudo install -Dm644 minecraft-launcher.svg /usr/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg`

Then  change the desktop file and make it available locally

`cp minecraft-launcher.desktop ~/.local/share/plasma_icons/`

## How to do reproduce manually what this launcher does

* Run the official java launcher. Login and start the game. The louncher will download all the required files for the new version. Alternatively grab [this manifest](https://launchermeta.mojang.com/mc/game/version_manifest.json).
* Find the native libraries `ps -ef | grep java.library.path` then copy that folder `cp -a /tmp/folder $HOME/.minecraft/versions/$ver/$ver-natives`. They can be found [here](https://libraries.minecraft.net/)
* Copy-paste the whole `-cp` argument from the java process, along with the java args to a run script. Run the script, plus assets, libraries, and version folder what you need.

To learn more details of the files that Minecraft uses, see [this page](https://wiki.vg/Game_files).

