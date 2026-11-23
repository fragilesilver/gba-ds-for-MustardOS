[muOS](https://muos.dev) (MustardOS) runs on single-screen handhelds: Anbernic's RG35XX, RG40XX, RG34XX and RG CubeXX families, the TrimUI Brick and others. **GBA DS External Core** is GBA DS packaged for muOS 2606 Andromeda and 2612 Supernova: an app of its own, and a Game Boy Advance core you can assign in muOS, like DraStic for the DS. *Tried on muOS 2612 Supernova; 2606 Andromeda is checked against muOS's own scripts but hasn't been tried on a device yet. Download it from this fork's [Releases](https://github.com/fragilesilver/gba-ds-for-MustardOS/releases), and report anything that doesn't work in its [issues](https://github.com/fragilesilver/gba-ds-for-MustardOS/issues).*

## One screen, two pictures

These handhelds have one screen, so GBA DS splits it (Settings → Screens → **Layout: Game and second screen**, set the first time it runs): the game gets two thirds, pixel perfect, and the second screen (the game's map, or what it shows for that game) the rest. Which way it splits is whichever gives the game the bigger picture:

| Screen | The game | The second screen |
|---|---|---|
| 640x480 (RG35XX, RG40XX) | 640x320 on top: 2x | 640x160 below: 1x |
| 720x480 (RG34XX) | 720x320 on top: 2x | 720x160 below: 1x |
| 720x720 (RG CubeXX) | 720x480 on top: 3x | 720x240 below: 1x, 1.5x at Full Width |
| 1024x768 (TrimUI Brick) | 1024x512 on top: 3x | 1024x256 below: 1x, 1.6x at Full Width |
| 1920x1080 (HDMI, large screens) | 1280x1080 on the left: 5x | 640x1080 on the right |

- **Swap Screens** (HOME + D-pad up, or the pause menu) puts the game in the smaller part's place and keeps the larger part the game's.
- The game list and the pause menu open on the larger part; the game's logo and resume picture go in the smaller one.
- Games without second-screen support, or with Second screen off, get the whole screen.
- **Peek at the second screen** (Settings → Screens; off at first): choose X, Y or L3, and while you hold it the map fills the screen at twice the size; let go and the game is back. The game doesn't get that button.
- **Layout: Game only** gives every game the whole screen, as GBA DS does on any single screen: HOME + D-pad up then shows the map in the game's place. Layout can be set for one game too (the pause menu's Screens page, This game).

## Install

1. Download `gba-ds-external-core-v…+muos.muxapp` and copy it to the `ARCHIVE` folder at the root of the SD card.
2. On the device, open muOS's **Archive Manager** and install it. It goes into `MUOS/application/GBA DS`.
3. Open **Applications → GBA DS** once. This adds **GBA DS - External Core** to muOS's Game Boy Advance cores, and the game list opens: you can play from here.
4. To start games from muOS's own lists: highlight your GBA folder (or a single game), open **Core Assignment**, and choose **GBA DS - External Core** for the folder or that game. Closing a game (the pause menu's Close GBA DS, or muOS's quit) goes back to muOS.

Opening the app again puts the core back if a muOS update took it away. On Andromeda the core goes into your copy of muOS's core list (`MUOS/info/manifest/core.json`); on Supernova into your copy of the Game Boy Advance definition (`MUOS/info/manifest/core/Nintendo/Nintendo Game Boy Advance.json`). A copy GBA DS made is made again from muOS's own each time, so muOS's later changes still arrive; one you made yourself is kept, with the core added.

## How it fits in

- **Fast forward:** hold R2, or set Settings → Speed and sound → Fast forward button to *Press R2 to switch* to switch it on with one press and off with the next (a small "FF" in the corner shows it's on).
- **First start:** a card shows the buttons and hotkeys. muOS's MENU button is the hotkey button; Menu + Left / Right picks the save slot, and Menu + R1 / L1 save to and load from it.
- **Rumble and tilt:** Drill Dozer and WarioWare: Twisted! run the device's motor; Kirby Tilt 'n' Tumble, Yoshi Topsy-Turvy and WarioWare: Twisted! take tilting and turning from the left stick (Settings → Controls).
- **Sleep:** muOS asks only RetroArch to save before the device sleeps. Settings → Games → Save while playing keeps GBA DS's resume point current every few minutes instead, and Save backups keeps the last 3 versions of each battery save.
- **Speed:** muOS's Governor option for the content (or the folder) applies to GBA DS as to any core; *performance* gives it the most headroom. If the game still can't keep full speed, GBA DS refreshes the map less often and says so. GBA DS's own Settings → Speed and sound → Performance is best left at *Let the System Decide* on muOS.
- **Buttons:** GBA A is the right face button and B the bottom one, whichever controller layout muOS is set to (Retro or Modern); MENU is HOME. If a button is wrong on your device, Settings → Controls → Map Buttons maps them.
- **Quit and sleep:** muOS's own quit closes GBA DS as it does any core, and GBA DS saves where you are on the way out (Save on quit).
- **Where things go:** these replace ROCKNIX's paths unless you've changed them in `gba-ds.cfg`:

| | |
|---|---|
| Games (the app's list) | every Game Boy Advance folder in `ROMS` on either card (`GBA`, `Nintendo Game Boy Advance`, `Game Boy Advance`, `GBA Hacks`...) |
| Battery saves (`.srm`) | `MUOS/save/file/mGBA`: the same file RetroArch's mGBA core uses, so a game goes on from where you left it in either |
| Screenshots | `MUOS/screenshot` |
| Cheats | `MUOS/application/GBA DS/cheats`, and muOS's RetroArch cheats |
| Save states, settings from the menu, logos, patches | `MUOS/application/GBA DS/` (`states/`, `logos/`, `patches/`) |
| Logs | `MUOS/application/GBA DS/gba-ds.log`, and `core-install.log` for adding the core |

- **RetroAchievements:** the account in muOS's RetroArch settings is used (casual mode) when achievements are on there.
- **Updates:** this package doesn't check for updates (the releases on GitHub are the ROCKNIX and Android packages); install a newer `.muxapp` over it the same way. Your states and settings are kept.

## Remove

First give the folders and games you assigned to GBA DS another core in Core Assignment (once the app is gone, they won't start). Then, from a terminal or SSH, run `sh core.sh remove` in `MUOS/application/GBA DS` to take the core out of muOS's list, and delete that folder.
