#!/bin/sh
# HELP: GBA DS: Game Boy Advance games with the game's own map beside them. Opening it also adds GBA DS - External Core to your Game Boy Advance cores.
# ICON: gbads
# GRID: GBA DS

# The GBA DS app (Applications): the game list. Each time it opens it also
# puts "GBA DS - External Core" in muOS's Game Boy Advance cores (core.sh), so
# games can be started from muOS's own lists (Core Assignment on the GBA
# folder or a game). muOS runs it as mux_launch.sh APP_FOLDER.

. /opt/muos/script/var/func.sh

APP_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
APP_DIR="${APP_DIR%/}"
cd "$APP_DIR" || exit 1

sh ./core.sh install > "$APP_DIR/core-install.log" 2>&1 ||
	LOG_WARN "$0" 0 "GBA DS" "The external core couldn't be added: see $APP_DIR/core-install.log"

SETUP_APP gba-ds ""
sh ./muos-play.sh
