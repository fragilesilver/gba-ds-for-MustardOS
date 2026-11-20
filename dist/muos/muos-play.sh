#!/bin/sh
# GBA DS on muOS (MustardOS): runs GBA DS with muOS's folders and controls.
#   muos-play.sh            the game list (the GBA DS app, Applications)
#   muos-play.sh GAME.gba   one game, then back to muOS (the external core)
# Run by mux_launch.sh and by ext-gbads.sh, after muOS set SDL up
# (SETUP_SDL_ENVIRONMENT). POSIX sh: muOS may have no bash.
#
# What it sets, for the settings still at their defaults in gba-ds.cfg:
# - the game list's folders: every Game Boy Advance folder in ROMS on either card
# - battery saves shared with RetroArch's mGBA core (MUOS/save/file/mGBA/<game>.srm),
#   so a game goes on from the same save in either
# - screenshots in MUOS/screenshot, RetroArch's cheat files, and the
#   RetroAchievements account from muOS's RetroArch settings
# - the controls by position (GBA A on the right button, B on the bottom one),
#   from muOS's own mapping of the device
# - on the first run, Layout: Game and second screen (Settings > Screens)
# The log is gba-ds.log in the app's folder (written to memory during the
# run, then copied: the card never holds the game up).

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1
LOG="$DIR/gba-ds.log"
RUNLOG="/tmp/gba-ds.$$.log"
: > "$RUNLOG"
log() { printf '%s\n' "$*" >> "$RUNLOG"; }

STORE=/run/muos/storage
cfgval() { sed -n "s/^$1 *= *//p" "$DIR/gba-ds.cfg" 2>/dev/null | tail -n 1; }
# muOS's GET_VAR / SET_VAR (a shell of our own: the caller's functions aren't ours)
[ -f /opt/muos/script/var/config.sh ] && . /opt/muos/script/var/config.sh
getvar() { command -v GET_VAR >/dev/null 2>&1 && GET_VAR "$1" "$2" 2>/dev/null; }

log "GBA DS on muOS: $(head -n 1 /opt/muos/config/system/version 2>/dev/null) ($(getvar device board/name)), $(uname -r)"
OPTS=""
add() { OPTS="$OPTS
$1"; }

# --- the game list's folders (the app; a game given is played as it is) ---
if [ "$(cfgval rom_dir)" = /storage/roms/gba ]; then
	R=""
	for root in /mnt/union/ROMS /mnt/mmc/ROMS /mnt/sdcard/ROMS /mnt/usb/ROMS; do
		[ -d "$root" ] || continue
		for d in "$root"/*/; do
			[ -d "$d" ] || continue
			n=$(basename "$d" | tr 'A-Z' 'a-z')
			case "$n" in
			gba | "game boy advance" | "gameboy advance" | "nintendo game boy advance" | "nintendo gameboy advance" | gbadvance | "gba hacks" | gbahacks)
				d="${d%/}"
				case ":$R:" in *":$d:"*) ;; *) R="${R:+$R:}$d" ;; esac
				;;
			esac
		done
		[ "$root" = /mnt/union/ROMS ] && [ -n "$R" ] && break # (the union has both cards)
	done
	[ -z "$R" ] && R=/mnt/mmc/ROMS/GBA
	add "--rom-dir=$R"
fi

# --- battery saves: RetroArch's mGBA folder (sort_savefiles_enable: by core name) ---
if [ -z "$(cfgval save_dir)" ] && [ -d "$STORE/save/file" ]; then
	mkdir -p "$STORE/save/file/mGBA" 2>/dev/null
	add "--save-dir=$STORE/save/file/mGBA"
	add "--save-ext=srm"
fi
if [ "$(cfgval screenshot_dir)" = /storage/roms/screenshots ] && [ -d "$STORE/screenshot" ]; then
	add "--screenshot-dir=$STORE/screenshot"
fi
case "$(cfgval cheat_dir)" in
/config/retroarch/cheats* | "")
	for c in /opt/muos/share/emulator/retroarch/cheats "$STORE/info/cheats"; do
		[ -d "$c" ] && add "--cheat-dir=$c" && break
	done
	;;
esac

# --- RetroAchievements: the account in muOS's RetroArch settings ---
RA_CFG=/opt/muos/share/info/config/retroarch.cfg
if [ -z "$(cfgval ra_username)" ] && [ -f "$RA_CFG" ] && grep -q '^cheevos_enable *= *"true"' "$RA_CFG"; then
	u=$(sed -n 's/^cheevos_username *= *"\(.*\)"/\1/p' "$RA_CFG" | head -n 1)
	w=$(sed -n 's/^cheevos_password *= *"\(.*\)"/\1/p' "$RA_CFG" | head -n 1)
	[ -n "$u" ] && [ -n "$w" ] && add "--ra-username=$u" && add "--ra-password=$w" && log "RetroAchievements: $u (muOS's RetroArch account)"
fi

# --- controls by position ---
# muOS's "retro" mapping (its default) names the face buttons by their labels:
# SDL A is the right button. GBA DS reads them by position, as ROCKNIX gives
# them (SDL B right, A bottom, X top, Y left), so the device's line is turned
# round: A and B swapped, X and Y kept. A mapping made in GBA DS (Settings >
# Controls > Map Buttons) still wins over this.
SDLNAME=$(getvar device sdl/name)
GCDB=/opt/muos/share/info/gamecontrollerdb/retro.txt
if [ -n "$SDLNAME" ] && [ -f "$GCDB" ]; then
	LINE=$(grep -m1 ",$SDLNAME," "$GCDB")
	if [ -n "$LINE" ]; then
		ra=$(printf '%s' "$LINE" | sed -n 's/.*,a:\([^,]*\),.*/\1/p')
		rb=$(printf '%s' "$LINE" | sed -n 's/.*,b:\([^,]*\),.*/\1/p')
		if [ -n "$ra" ] && [ -n "$rb" ]; then
			POS=$(printf '%s' "$LINE" | sed "s/,a:$ra,/,a:@B@,/; s/,b:$rb,/,b:@A@,/; s/@B@/$rb/; s/@A@/$ra/")
			printf '%s\n' "$POS" > /tmp/gba-ds-gamecontrollerdb.txt
			export SDL_GAMECONTROLLERCONFIG_FILE=/tmp/gba-ds-gamecontrollerdb.txt
			export SDL_GAMECONTROLLERCONFIG="$POS"
			log "controls: $SDLNAME by position (a:$rb b:$ra)"
		fi
	fi
fi

# --- GBA DS's own files: this folder, or data_dir in data-folder.cfg ---
DATA=$(sed -n 's/^[[:space:]]*data_dir[[:space:]]*=[[:space:]]*//p' "$DIR/data-folder.cfg" 2>/dev/null | tail -n 1 | sed 's:/*[[:space:]]*$::')
case "$DATA" in /*) [ -d "$(dirname "$DATA")" ] || DATA="$DIR" ;; *) DATA="$DIR" ;; esac
# first run: the game with the second screen under it (a muOS device has one screen)
mkdir -p "$DATA/states"
PREFS="$DATA/states/prefs.cfg"
if ! grep -q '^layout *=' "$PREFS" 2>/dev/null; then
	[ -s "$PREFS" ] || echo "# written by gba-ds's menus; overrides gba-ds.cfg" > "$PREFS"
	echo "layout = focus" >> "$PREFS"
	log "first run: layout = focus (Settings > Screens > Layout)"
fi

# --- the program: here, or a copy in memory where the card won't run programs ---
GBADS=./gba-ds
[ -x ./gba-ds ] || chmod +x ./gba-ds 2>/dev/null
if ! ./gba-ds --version >/dev/null 2>&1; then
	GBADS=
	for t in /tmp /dev/shm; do
		if cp ./gba-ds "$t/gba-ds" 2>/dev/null && chmod +x "$t/gba-ds" && "$t/gba-ds" --version >/dev/null 2>&1; then
			GBADS="$t/gba-ds"
			export GBADS_HOME="$DIR"
			log "this folder can't run programs: running a copy of gba-ds from $t"
			break
		fi
	done
	if [ -z "$GBADS" ]; then
		log "gba-ds won't run here: $(./gba-ds --version 2>&1 | head -n 2)"
		cat "$RUNLOG" > "$LOG"; rm -f "$RUNLOG"
		exit 1
	fi
fi
# muOS's quit and sleep find the game by this name (pidof)
command -v SET_VAR >/dev/null 2>&1 && SET_VAR "system" "foreground_process" "gba-ds"

# the options, one per line, ahead of the game (if any)
OLDIFS=$IFS
IFS='
'
set -f
# shellcheck disable=SC2086
set -- $OPTS "$@"
set +f
IFS=$OLDIFS
log "options: $(printf '%s ' "$@" | sed 's/--ra-password=[^ ]*/--ra-password=.../')"

"$GBADS" "$@" >> "$RUNLOG" 2>&1
st=$?
cat "$RUNLOG" > "$LOG" 2>/dev/null
rm -f "$RUNLOG"
[ "$GBADS" = ./gba-ds ] || rm -f "$GBADS"
# (64 means "switch to other content" to muOS's launcher: never pass it on)
[ $st = 64 ] && st=1
exit $st
