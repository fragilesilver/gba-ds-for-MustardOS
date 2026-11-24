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
# - on the first run, Layout: Game and second screen (Settings > Screens),
#   save states shared with RetroArch's mGBA core, and muOS's GBA BIOS (if
#   it has one) where Settings > System > GBA BIOS finds it
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
# (and RetroArch's own settings, for its save state folder: see "save states" below)
[ -z "$(cfgval retroarch_cfg)" ] && [ -f "$RA_CFG" ] && add "--retroarch-cfg=$RA_CFG"
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

# --- the rumble motor: where muOS says it is, written as muOS's own RUMBLE
# writes it (script/var/display.sh): most boards 1 on / 0 off, the RK ones'
# PWM 1 / 1000000, the RG Vita Pro's 0 / 1 ---
RUMBLE_PATH=$(getvar device board/rumble)
if [ -n "$RUMBLE_PATH" ] && [ -e "$RUMBLE_PATH" ]; then
	case "$(getvar device board/name)" in
	rk-g350-v) R_ON=1 R_OFF=0 ;;
	rk*) R_ON=1 R_OFF=1000000 ;;
	rg-vita*) R_ON=0 R_OFF=1 ;;
	*) R_ON=1 R_OFF=0 ;;
	esac
	export GBADS_RUMBLE="$RUMBLE_PATH|$R_ON|$R_OFF"
	log "rumble: $GBADS_RUMBLE"
fi
# muOS's MENU button is GBA DS's HOME: named so on the controls card
add "--home-name=Menu"
# the CPU governor muOS set for this content (its Governor option), for reports
log "governor: $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unknown)"

# --- GBA DS's own files: this folder, or data_dir in data-folder.cfg ---
DATA=$(sed -n 's/^[[:space:]]*data_dir[[:space:]]*=[[:space:]]*//p' "$DIR/data-folder.cfg" 2>/dev/null | tail -n 1 | sed 's:/*[[:space:]]*$::')
case "$DATA" in /*) [ -d "$(dirname "$DATA")" ] || DATA="$DIR" ;; *) DATA="$DIR" ;; esac
# first run: the game with the second screen under it (a muOS device has one screen)
mkdir -p "$DATA/states"
PREFS="$DATA/states/prefs.cfg"
[ -s "$PREFS" ] || echo "# written by gba-ds's menus; overrides gba-ds.cfg" > "$PREFS"
first() { # KEY VALUE: written once, then the menus' to change
	grep -q "^$1 *=" "$PREFS" 2>/dev/null && return
	echo "$1 = $2" >> "$PREFS"
	log "first run: $1 = $2"
}
first layout focus                 # Settings > Screens > Layout
first hotkey_states slot           # Menu + R1 / L1 save and load the slot Menu + Left / Right picks
# the second screen's strip has room for more than 1x on these screens
# (720x240 on 720x720, 1024x256 on 1024x768): Full Width fills it
case "$(getvar device mux/width)x$(getvar device mux/height)" in
720x720 | 1024x768) first map_scale fit ;;
esac
# the toggle's on-screen key is for touchscreens: Menu + A turns the second screen here
first toggle_button off

# --- a GBA BIOS: muOS's own (MUOS/bios/gba_bios.bin), copied to where GBA DS
# looks for one (its data folder's bios/), for Settings > System > GBA BIOS.
# It stays off until switched on there, as everywhere. ---
for b in "$STORE/bios/gba_bios.bin" /mnt/mmc/MUOS/bios/gba_bios.bin /mnt/sdcard/MUOS/bios/gba_bios.bin; do
	[ -f "$b" ] || continue
	[ "$(wc -c < "$b" 2>/dev/null | tr -d ' ')" = 16384 ] || continue
	if [ ! -f "$DATA/bios/gba_bios.bin" ] || ! cmp -s "$b" "$DATA/bios/gba_bios.bin"; then
		mkdir -p "$DATA/bios" && cp "$b" "$DATA/bios/gba_bios.bin" && log "GBA BIOS: copied from $b"
	fi
	break
done

# --- save states: shared with RetroArch's mGBA core (once; Settings > System >
# Save States switches them back to GBA DS's own) ---
# Slots 0-9 and the resume point become RetroArch's files in its state folder
# (MUOS/save/state/mGBA/<game>.state, .state1-.state9, .state.auto), so a state
# saved in either loads in the other. States GBA DS kept of its own are copied
# there first, where RetroArch has none of that name (the originals stay in
# states/, for when it's switched back). The quick state stays GBA DS's.
LIBCFG="$DATA/states/library.cfg"
if [ ! -f "$DATA/states/muos-states-shared" ] && [ -f "$RA_CFG" ]; then
	raval() { sed -n "s/^$1 *= *\"\(.*\)\"/\1/p" "$RA_CFG" | tail -n 1; }
	SDIR=$(raval savestate_directory)
	if [ -n "$SDIR" ] && [ "$SDIR" != default ] && [ "$(raval savestates_in_content_dir)" != true ] \
	   && [ "$(raval sort_savestates_by_content_enable)" != true ]; then
		[ "$(raval sort_savestates_enable)" = false ] || SDIR="${SDIR%/}/mGBA"
		mkdir -p "$SDIR" 2>/dev/null
		n=0
		for f in "$DATA"/states/*.slot[0-9].state "$DATA"/states/*.auto.state; do
			[ -f "$f" ] || continue
			b=$(basename "$f")
			case "$b" in
			*.auto.state) to="${b%.auto.state}.state.auto" ;;
			*.slot0.state) to="${b%.slot0.state}.state" ;;
			*) k=${b%.state}; k=${k##*.slot}; to="${b%.slot[0-9].state}.state$k" ;;
			esac
			[ -e "$SDIR/$to" ] && continue
			cp -p "$f" "$SDIR/$to" && n=$((n + 1))
		done
		if [ -f "$LIBCFG" ] && grep -q '^state_folder *=' "$LIBCFG"; then
			sed -i 's/^state_folder *=.*/state_folder = retroarch/' "$LIBCFG"
		else
			echo "state_folder = retroarch" >> "$LIBCFG"
		fi
		: > "$DATA/states/muos-states-shared"
		log "save states: shared with RetroArch in $SDIR ($n of GBA DS's own copied there)"
	else
		log "save states: RetroArch keeps its states by game folder here, so GBA DS's stay its own"
		: > "$DATA/states/muos-states-shared"
	fi
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
