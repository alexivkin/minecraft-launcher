# A Better Mincraft launcher for Linux

A smarter way of managing multiple minecraft installations on Linux. It downloads and installs Minecraft version on demand, including all the appropriate libraries and assets.
Pairs well with the [minecraft server launcher for Linux](https://github.com/alexivkin/minecraft-server-container). 

* Supports the normal (aka vanilla/mainline) and Forge Minecraft versions on-demand installation. 
* Works with offline game profiles
* Allows multiple versions, player profiles, and game mod configurations to be accessible at the same time.
* Keeps game assets separate from profiles and versioned libraries for easier file management

## Running

Prerequisites: make sure you have the following tools installed: `jq`,`unzip`,`curl`, `sha1sum`

Running: `./start <version> <player_nick>`

* To run a Forge version add a suffix "-forge" to the version, for example `./start 1.17.10-forge player1`. 
* To see what normal and Forge versions are currently available for installation, run the script with a non-existing version, like this `./start 0 player1`, `./start 0-forge player1`
* To create a game profiles with the same game version and same player name, for example to try out different mods, specify a name of this profile as the last argument `./start <version> <player_nick> <profile>` 

## Troubleshooting

1. Delete the version subfolder under "versons" and re-run it to download and rebuild everything. The versions and player profiles are kept in separate folders, so you can remove versions without removing player configuration.
2. If #1 did not work for a Forge version, remove both the Forge and the the corresponding mainline version folders under "versions" and run it again to re-download everything. 

## How to add it to the KDE desktop 

To get the minecraft icon and the desktop link clone [this repo](https://aur.archlinux.org/minecraft-launcher.git), To install the icon run

`sudo install -Dm644 minecraft-launcher.svg /usr/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg`

Then change the desktop file to run this launcher and make it available locally

`cp minecraft-launcher.desktop ~/.local/share/plasma_icons/`

## How to do reproduce manually what this launcher does

* Run the official java launcher. Login and start the game. The launcher will download all the required files for the new version. You can see them in [this manifest](https://launchermeta.mojang.com/mc/game/version_manifest.json).
* Find the native libraries in the process name with `ps -ef | grep java.library.path`. Then copy that folder `cp -a /tmp/folder $HOME/.minecraft/versions/$ver/$ver-natives`. The native libraries can be found [here](https://libraries.minecraft.net/).
* Copy-paste the whole `-cp` argument from the java process, along with the java args to a run script. Run the script, plus assets, libraries, and version folder what you need.

To learn more about the files that Minecraft uses, see [this page](https://wiki.vg/Game_files).

