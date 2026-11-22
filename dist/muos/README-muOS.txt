GBA DS External Core for muOS (MustardOS 2606 Andromeda, 2612 Supernova)
=======================================================================

GBA DS plays Game Boy Advance games with the game's own map (or other
second-screen picture) beside the game. muOS handhelds have one screen, so
GBA DS splits it: the game gets the larger part, pixel perfect, and the
second screen the rest (on a 640x480 screen: the game at 2x on top, the map
at 1x below it).

Install
-------
1. Copy gba-ds-external-core-v...+muos.muxapp to the card's MUOS/ARCHIVE folder.
2. On the device, open muOS's Archive Manager, choose the archive and
   install it. It goes into MUOS/application/GBA DS.
3. Open Applications > GBA DS once. This adds "GBA DS - External Core" to
   muOS's Game Boy Advance cores (and puts it back after a muOS update takes
   it away). The game list opens: you can play from here too.
4. To start games from muOS's own Game Boy Advance list: highlight the GBA
   folder (or one game), open Core Assignment, and choose
   "GBA DS - External Core" (for the folder, or just that game).

Your games
----------
- The game list shows every Game Boy Advance folder in ROMS on either card
  (GBA, "Nintendo Game Boy Advance", ...).
- Battery saves are shared with RetroArch's mGBA core
  (MUOS/save/file/mGBA/<game>.srm): a game goes on from the same save in
  either one.
- Screenshots go to MUOS/screenshot. RetroArch's cheat files are found.
- RetroAchievements uses the account in muOS's RetroArch settings.

Controls
--------
- MENU: GBA DS's menu (save and load states, settings, close the game).
- R2: fast forward (hold, or press to switch it on and off: Settings >
  Speed and sound > Fast forward button).
- Peek: Settings > Screens > Peek at the second screen picks X, Y or L3;
  hold it and the map fills the screen, let go and the game is back.
- MENU + Left / Right: pick the save slot; MENU + R1 / L1: save / load it.
- Rumble (Drill Dozer, WarioWare: Twisted!) and tilt from the left stick
  (Kirby Tilt 'n' Tumble, Yoshi Topsy-Turvy): Settings > Controls.
- Settings > Games: Save while playing (every few minutes, for sleep),
  Save backups (last 3 versions of each save), Low battery warning.
- MENU + Up: swap the game and the second screen. More hotkeys in
  Settings > Controls > Hotkeys.
- GBA A is the right face button and B the bottom one, whichever controller
  layout muOS is set to. If buttons are wrong on your device,
  Settings > Controls > Map Buttons maps them (and A and B buttons swaps them).
- muOS's own quit and sleep work as for any other core: GBA DS saves where
  you are on the way out (Settings > Games > Save on quit).

The screen
----------
Settings > Screens > Layout (or the pause menu's Screens page, for one game):
- Game and second screen (set on the first run): the split described above.
- Game only: the whole screen for the game; MENU + Up shows the map instead.
Games without second-screen support always get the whole screen.

Remove
------
First give the games and folders you assigned to GBA DS another core in
Core Assignment (once the app is gone, those games won't start). Then take
the core out of muOS's list with "sh core.sh remove" in MUOS/application/GBA DS
(from a terminal or SSH), and delete that folder.

Logs: gba-ds.log and core-install.log in MUOS/application/GBA DS.

This is GBA DS by kyannon (https://github.com/kyannon/gba-ds), with muOS
support added in https://github.com/fragilesilver/gba-ds. Free software,
GPL version 3 (licenses/).
