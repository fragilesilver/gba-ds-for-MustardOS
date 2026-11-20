#!/bin/sh
# GBA DS External Core for muOS (MustardOS): adds "GBA DS - External Core" to
# the Game Boy Advance cores muOS offers (Core Assignment), or takes it out.
#
#   core.sh install   (run by the GBA DS app each time it opens: it puts the
#                      core back after a muOS update took it away)
#   core.sh remove
#   core.sh status
#
# Two kinds of muOS are handled:
# - 2606 Andromeda: every system's cores in one core.json. muOS reads the
#   user's copy, /run/muos/storage/info/manifest/core.json (MUOS/info/manifest
#   on the card), instead of the bundled /opt/muos/share/info/manifest/core.json
#   when it exists, so the user's copy is the bundled one plus our core.
# - 2612 Supernova and later: one file per system,
#   core/<Namespace>/<System>.json; a user file of the same name in
#   MUOS/info/manifest/core replaces that one system, so ours is the
#   Game Boy Advance file (downloaded or bundled) plus our core.
# A user file this script wrote is made again from muOS's own each time (so
# muOS's later changes to the system still arrive); one the user made or
# changed is kept, with our core added to it.
#
# The launcher, ext-gbads.sh, goes into /opt/muos/script/launch/, where muOS
# looks for a core's "launcher" (ext- + gbads.sh).
#
# POSIX sh (muOS's scripts are; there may be no bash). Needs jq (muOS has it).

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
SYSTEM="Nintendo Game Boy Advance"
NAMESPACE="Nintendo"
CORE_KEY="gba ds - external core"
R="${GBADS_MUOS_ROOT:-}" # (tests: a copy of muOS's folders)
LAUNCH_DIR="$R/opt/muos/script/launch"
LAUNCHER="$LAUNCH_DIR/ext-gbads.sh"
SHARE_DIR="$R/opt/muos/share"
STORE_DIR="$R/run/muos/storage"
WRITTEN="$APP_DIR/states/muos-core-written.json" # the last user file we wrote, to know it's ours

ENTRY='{"name":"GBA DS - External Core","core":"ext-gbads","launcher":"gbads.sh","require":{"arch":["aarch64"]}}'

say() { printf 'gba-ds core: %s\n' "$*"; }

need_jq() {
	command -v jq >/dev/null 2>&1 && return 0
	say "jq is missing: can't change muOS's core list"
	exit 1
}

# replace a file in one step (a half-written core list would break every system)
put_file() { # SRC-TEXT-FILE DEST
	mkdir -p "$(dirname "$2")" || return 1
	cp "$1" "$2.gbads-tmp" && mv -f "$2.gbads-tmp" "$2"
}

# Supernova (per-system files) or Andromeda (one core.json)
layout() {
	if [ -f "$R/opt/muos/script/var/manifest.sh" ] || [ -d "$SHARE_DIR/info/manifest/core" ]; then
		echo split
	elif [ -f "$SHARE_DIR/info/manifest/core.json" ] || [ -f "$STORE_DIR/info/manifest/core.json" ]; then
		echo single
	else
		echo none
	fi
}

# the first valid <system>.json in a manifest folder's namespace folders
find_system() { # DIR
	for f in "$1"/*/"$SYSTEM.json"; do
		[ -f "$f" ] && jq -e 'type == "object"' "$f" >/dev/null 2>&1 && { echo "$f"; return 0; }
	done
	return 1
}

ours() { # FILE: the user file is the one this script wrote last
	[ -f "$WRITTEN" ] && [ -f "$1" ] && cmp -s "$1" "$WRITTEN"
}

install_launcher() {
	tmp="/tmp/ext-gbads.sh.$$"
	# (the app's folder written in, so the launcher finds it)
	sed "s#^GBADS_APP=.*#GBADS_APP=\"$APP_DIR\"#" "$APP_DIR/ext-gbads.sh" > "$tmp" || return 1
	if [ -f "$LAUNCHER" ] && cmp -s "$tmp" "$LAUNCHER"; then
		rm -f "$tmp"
		return 0
	fi
	if ! { mkdir -p "$LAUNCH_DIR" && cp "$tmp" "$LAUNCHER.gbads-tmp" && chmod 755 "$LAUNCHER.gbads-tmp" && mv -f "$LAUNCHER.gbads-tmp" "$LAUNCHER"; }; then
		rm -f "$tmp" "$LAUNCHER.gbads-tmp"
		say "couldn't write $LAUNCHER"
		return 1
	fi
	rm -f "$tmp"
	say "launcher: $LAUNCHER"
}

install_split() {
	user_dir="$STORE_DIR/info/manifest/core"
	user_file="$(find_system "$user_dir")"
	if [ -n "$user_file" ] && ! ours "$user_file"; then
		base="$user_file" # the user's own: our core added to it
	else
		base="$(find_system "$STORE_DIR/info/manifest/coresync" || find_system "$SHARE_DIR/info/manifest/core")"
	fi
	if [ -z "$base" ]; then
		say "no $SYSTEM definition found: is this muOS 2612 or later?"
		return 1
	fi
	dest="${user_file:-$user_dir/$NAMESPACE/$SYSTEM.json}"
	tmp="/tmp/gbads-core.$$"
	jq --indent 4 --arg k "$CORE_KEY" --argjson e "$ENTRY" '.external = ((.external // {}) + {($k): $e})' "$base" > "$tmp" || { rm -f "$tmp"; return 1; }
	if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
		rm -f "$tmp"
	else
		put_file "$tmp" "$dest" || { rm -f "$tmp"; say "couldn't write $dest"; return 1; }
		say "core added: $dest (from $base)"
		rm -f "$tmp"
	fi
	# (made from muOS's own definition: ours, to make again next time; the
	# user's own file stays theirs)
	[ "$base" != "$user_file" ] && mkdir -p "$(dirname "$WRITTEN")" && cp "$dest" "$WRITTEN"
	return 0
}

install_single() {
	user="$STORE_DIR/info/manifest/core.json"
	bundled="$SHARE_DIR/info/manifest/core.json"
	if [ -f "$user" ] && jq -e 'type == "object"' "$user" >/dev/null 2>&1 && ! ours "$user"; then
		base="$user"
	elif [ -f "$bundled" ]; then
		base="$bundled"
	else
		say "no core.json found"
		return 1
	fi
	if ! jq -e --arg s "$SYSTEM" 'has($s)' "$base" >/dev/null 2>&1; then
		say "$SYSTEM isn't in $base"
		return 1
	fi
	tmp="/tmp/gbads-core.$$"
	jq --indent 4 --arg s "$SYSTEM" --arg k "$CORE_KEY" --argjson e "$ENTRY" \
		'.[$s].external = ((.[$s].external // {}) + {($k): $e})' "$base" > "$tmp" || { rm -f "$tmp"; return 1; }
	if [ -f "$user" ] && cmp -s "$tmp" "$user"; then
		rm -f "$tmp"
	else
		put_file "$tmp" "$user" || { rm -f "$tmp"; say "couldn't write $user"; return 1; }
		say "core added: $user (from $base)"
		rm -f "$tmp"
	fi
	[ "$base" = "$bundled" ] && mkdir -p "$(dirname "$WRITTEN")" && cp "$user" "$WRITTEN"
	return 0
}

remove_split() {
	f="$(find_system "$STORE_DIR/info/manifest/core")" || return 0
	if ours "$f"; then
		rm -f "$f" && say "removed $f"
	else
		tmp="/tmp/gbads-core.$$"
		jq --indent 4 --arg k "$CORE_KEY" 'if .external then .external |= del(.[$k]) else . end' "$f" > "$tmp" && put_file "$tmp" "$f" && say "core taken out of $f"
		rm -f "$tmp"
	fi
}

remove_single() {
	user="$STORE_DIR/info/manifest/core.json"
	[ -f "$user" ] || return 0
	if ours "$user"; then
		rm -f "$user" && say "removed $user"
	else
		tmp="/tmp/gbads-core.$$"
		jq --indent 4 --arg s "$SYSTEM" --arg k "$CORE_KEY" 'if .[$s].external then .[$s].external |= del(.[$k]) else . end' "$user" > "$tmp" &&
			put_file "$tmp" "$user" && say "core taken out of $user"
		rm -f "$tmp"
	fi
}

case "$1" in
install)
	need_jq
	install_launcher || exit 1
	case "$(layout)" in
	split) install_split ;;
	single) install_single ;;
	*) say "not muOS (no core definitions found)"; exit 1 ;;
	esac
	;;
remove)
	need_jq
	case "$(layout)" in
	split) remove_split ;;
	single) remove_single ;;
	esac
	rm -f "$LAUNCHER" "$WRITTEN"
	say "removed (games assigned to it go back to muOS's default core)"
	;;
status)
	echo "muOS core layout: $(layout)"
	[ -f "$LAUNCHER" ] && echo "launcher: $LAUNCHER" || echo "launcher: not installed"
	case "$(layout)" in
	split) f="$(find_system "$STORE_DIR/info/manifest/core")" ;;
	single) f="$STORE_DIR/info/manifest/core.json" ;;
	esac
	if [ -n "$f" ] && [ -f "$f" ] && grep -q '"ext-gbads"' "$f"; then echo "core: in $f"; else echo "core: not listed"; fi
	;;
*)
	echo "usage: $0 install | remove | status" >&2
	exit 2
	;;
esac
