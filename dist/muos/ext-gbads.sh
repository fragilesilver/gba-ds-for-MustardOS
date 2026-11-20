#!/bin/sh
# GBA DS External Core: muOS's launcher for a Game Boy Advance game assigned
# to "GBA DS - External Core". core.sh copies it to
# /opt/muos/script/launch/ext-gbads.sh with GBADS_APP set to the app's folder.
# muOS runs it as: ext-gbads.sh NAME CORE ROM (script/mux/launch.sh), and goes
# back to its menu when it ends.

GBADS_APP=""

. /opt/muos/script/var/display.sh
. /opt/muos/script/var/launch.sh # NAME, CORE, FILE (the ROM), HOME

# the app's folder: as installed, or wherever it is now (moved to the other card)
if [ ! -f "$GBADS_APP/muos-play.sh" ]; then
	GBADS_APP=
	for d in /run/muos/storage/application/*/ /mnt/mmc/MUOS/application/*/ /mnt/sdcard/MUOS/application/*/; do
		if [ -f "$d/muos-play.sh" ] && [ -f "$d/gba-ds" ]; then
			GBADS_APP="${d%/}"
			break
		fi
	done
fi
if [ -z "$GBADS_APP" ]; then
	LOG_ERROR "$0" 0 "GBA DS" "The GBA DS app isn't installed (MUOS/application/GBA DS): install GBA DS again"
	exit 1
fi

SETUP_SDL_ENVIRONMENT
sh "$GBADS_APP/muos-play.sh" "$FILE"
