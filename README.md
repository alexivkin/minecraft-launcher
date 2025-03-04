# A Better Mincraft launcher for Linux

A smarter way of managing multiple minecraft installations on Linux. It supports multiple versions, users and profiles in parallel, including normal (aka vanilla/mainline) Minecraft, **Forge** and **NeoForge**.
Pairs well with the [minecraft server launcher for Linux](https://github.com/alexivkin/minecraft-server-container).

* Fully automated, command line installation of all versions of Minecraft, Forge and NeoForge.
* Allows multiple versions, player profiles, and game mod configurations to be installed and run at the same time.
* Supports offline game profiles.

Please consider supporting the Forge project and NeoForge projects directly.

## Running

Prerequisites: make sure you have Java and the following tools installed: `jq`,`unzip`,`curl`, `sha1sum`

Running: `./start <version> <player_nick> [profile] [game arguments]`

* To run a Forge version add a suffix "-forge" to the version, for example `./start 1.17.10-forge player1`. For NeoForge use `./start 1.17.10-neoforge player1`
* If you are not sure what versions are available, run `./list-versions.sh`
* To create another game profile with the same game version and same player name, for example to try out different mods, specify a name of the new profile as the last argument `./start <version> <player_nick> <profile>`
* To run the game with additional arguments, add them as the last arguments.

## Troubleshooting

1. Force re-download by deleting the relevant minecraft version subfolder under `versons` and re-run `./start` to download and rebuild everything. The player profiles is kept in separate folders, under `profiles`, so you can remove versions without removing player configuration.
2. If the step above did not work for a (Neo)Forge version, remove both the (Neo)Forge and the the corresponding mainline version folders under `versions` and run `./start` again to re-download everything.
3. Run `./check-assets.sh` script to validate downloaded assets for correctness

## How to add it to the desktop

Download and install the minecraft icon

```
curl -O https://launcher.mojang.com/download/minecraft-launcher.svg
sudo install -Dm644 minecraft-launcher.svg /usr/share/icons/hicolor/symbolic/apps/minecraft-launcher.svg
```

Then edit `minecraft.desktop` to set the `<version>` and `<player>` you want, and copy it to `~/.local/share/applications/`.

## How to do reproduce manually what this launcher does

* Run the official java launcher. Login and start the game. The launcher will download all the required files for the new version. You can see them in [this manifest](https://launchermeta.mojang.com/mc/game/version_manifest.json).
* Find the native libraries in the process name with `ps -ef | grep java.library.path`. Then copy that folder `cp -a /tmp/folder $HOME/.minecraft/versions/$ver/$ver-natives`. The native libraries can be found [here](https://libraries.minecraft.net/).
* Copy-paste the whole `-cp` argument from the java process, along with the java args to a run script. Run the script, plus assets, libraries, and version folder what you need.

To learn more about the files that Minecraft uses, see [this page](https://wiki.vg/Game_files).
