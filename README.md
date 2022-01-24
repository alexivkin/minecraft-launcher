# A Better Mincraft launcher for Linux

A smarter way of managing multiple minecraft installations on Linux. It downloads and installs Minecraft version on demand, including all the appropriate libraries and assets.
Pairs well with the [minecraft server launcher for Linux](https://github.com/alexivkin/minecraft-server-container). 

* Supports the normal (vanilla/mainline) and Forge version on-demand installation. 
* Works with offline game profiles
* Many versions, player profiles, and game profiles (mod configurations) at the same time.
* Better version and space management by keeping all assets together but all libraries in Minimal extra space used by sharing the asset folder among all versions

## Running

* Prerequisites. Make sure you have the following tools installed: `jq`,`unzip`,`curl`, `sha1sum`
* Running - `./start <version> <player_nick> [profile]` where nick is anything you want, and the profile is optional
* To run a Forge version add a suffix "-forge" to the version. For example `./start 1.17.10-forge player1`. 

If you want to see what normal and Forge versions are currently available, run the script with a non-existing version, like this `./start 0 player1`, `./start 0-forge player1`

Multiple game profiles can be created using the same game version and same player name, which allows running the same game with different mods

## Troubleshooting

1. Delete the version subfolder under "versons" and re-run it to download and rebuild everything. The versions and player profiles are kept in separate folders, so you can remove versions without removing player configuration.
2. If #1 did not work for a Forge version, remove both the forge and the the corresponding mainline version folders under "versions" and re-run it 

## How to add it to the KDE desktop 

To get the minecraft icon and the desktop link clone [this repo](https://aur.archlinux.org/minecraft-launcher.git), To install the icon run

`sudo install -Dm644 minecraft-launcher.svg /usr/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg`

Then change the desktop file to run this launcher and make it available locally

`cp minecraft-launcher.desktop ~/.local/share/plasma_icons/`

## How to do reproduce manually what this launcher does

* Run the official java launcher. Login and start the game. The louncher will download all the required files for the new version. Alternatively grab [this manifest](https://launchermeta.mojang.com/mc/game/version_manifest.json).
* Find the native libraries `ps -ef | grep java.library.path` then copy that folder `cp -a /tmp/folder $HOME/.minecraft/versions/$ver/$ver-natives`. They can be found [here](https://libraries.minecraft.net/)
* Copy-paste the whole `-cp` argument from the java process, along with the java args to a run script. Run the script, plus assets, libraries, and version folder what you need.

To learn more details of the files that Minecraft uses, see [this page](https://wiki.vg/Game_files).

