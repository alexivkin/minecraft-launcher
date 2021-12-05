# A custom Mincraft launcher in Bash

A fully command line, better, easier way of managing multiple mincraft installations. Pairs well with the [minecraft server launcher for Linux](https://github.com/alexivkin/minecraft-server-container).
Downloads and installs Minecraft version on demand, including all the appropriate libraries. Supports normal and Forge versions. The versions and player profiles are kept in separate folders so you can have many versions and players at the same time. 


* Prerequisites - `jq`,`unzip`,`curl`. 
* Running

`./start <player nick> version`

To get the minecraft icon and the desktop link clone [this repo](https://aur.archlinux.org/minecraft-launcher.git), To install the icon run

`sudo install -Dm644 minecraft-launcher.svg /usr/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg`

Then  change the desktop file and make it available locally

`cp minecraft-launcher.desktop ~/.local/share/plasma_icons/`


## How to do replicate manually what it does

* Run the official java launcher
* Login and start the game from the launcher. The louncher will download all the new files for the new version. Alternatively grab [this manifest](https://launchermeta.mojang.com/mc/game/version_manifest.json)
* Copy the nativelibraries. Find them `ps -ef | grep java.library.path` then copy that folder `cp -a /tmp/folder $HOME/.minecraft/versions/$ver/$ver-natives. They can be found [here](https://libraries.minecraft.net/)
* Copy-paste the whole -cp argument from the java process, along with the java args to a run script. Run the script, plus assets, libraries, and version folder what you need.

Details of hte [files Minecraft users](https://wiki.vg/Game_files)
