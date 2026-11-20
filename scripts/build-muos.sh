#!/bin/bash
# Cross-build of GBA DS External Core for muOS (MustardOS 2606 Andromeda and
# 2612 Supernova; aarch64) on an x86_64 Linux host.
# Produces dist/gba-ds-external-core-v<VERSION>-muos.muxapp: a muOS application
# archive (a zip that muOS's Archive Manager unpacks into MUOS/application),
# holding the app "GBA DS" (Applications), which on opening adds
# "GBA DS - External Core" to muOS's Game Boy Advance cores (dist/muos/core.sh).
#
# Needs: git, cmake, make, zip, an x86_64 host. Everything else is fetched into
# ./deps (scripts/aarch64-deps.sh, shared with build-rocknix.sh).
#
# Built for Cortex-A53 (plain ARMv8.0: the H700 and RK3326 devices muOS runs
# on), with no update checks (the GitHub release is the ROCKNIX package: an
# update would replace this one with it).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
DEPS="$ROOT/deps"
mkdir -p "$DEPS"
. scripts/mgba-options.sh   # MGBA_OPTS, MGBA_COMMIT, SDL_BRANCH

AARCH64_CPU=cortex-a53
. scripts/aarch64-deps.sh   # CROSS, MGBA_BUILD_DIR, DEPS/sdl-aarch64

# --- gba-ds ---------------------------------------------------------------
OUT=build/aarch64-muos
make CROSS="$CROSS" MGBA_SRC="$DEPS/mgba" MGBA_BUILD="$MGBA_BUILD_DIR" \
	SDL_PREFIX="$DEPS/sdl-aarch64" OUT="$OUT" OPTFLAGS="-O2 -mcpu=$AARCH64_CPU" NO_UPDATES=1

# glibc: muOS 2606 has 2.38 (its own programs ask for up to GLIBC_2.38)
NEED=$("${CROSS}objdump" -T "$OUT/gba-ds" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1)
echo "gba-ds needs $NEED"
if [ "$(printf '%s\nGLIBC_2.38\n' "$NEED" | sort -V | tail -n 1)" != GLIBC_2.38 ]; then
	echo "gba-ds needs $NEED, newer than muOS's glibc 2.38" >&2
	exit 1
fi

# --- package ---------------------------------------------------------------
VERSION=$(cat VERSION)
APP="GBA DS"                       # MUOS/application/GBA DS
ARCHIVE="gba-ds-external-core-v$VERSION-muos.muxapp"
PKG="$ROOT/build/pkg-muos/$APP"
rm -rf "$ROOT/build/pkg-muos"
mkdir -p "$PKG"
"${CROSS}strip" -o "$PKG/gba-ds" "$OUT/gba-ds"
cp dist/muos/mux_launch.sh dist/muos/mux_lang.ini dist/muos/muos-play.sh dist/muos/ext-gbads.sh dist/muos/core.sh "$PKG/"
cp -r dist/muos/glyph "$PKG/glyph"
cp dist/muos/README-muOS.txt "$PKG/README-muOS.txt"
cp dist/gba-ds.cfg dist/gamecontrollerdb.txt "$PKG/"
mkdir -p "$PKG/logos" "$PKG/cheats" "$PKG/overlays" "$PKG/patches"
printf "Optional: your own logo images (<CODE>.png or .bmp) override the ones extracted from the games.\n" > "$PKG/logos/README.txt"
printf "RetroArch cheat files (.cht) for GBA DS, in this folder or subfolders: picked by name, as RetroArch does (Game (USA).gba -> Game (USA) (Code Breaker).cht).\nmuOS's RetroArch cheats are searched too. Switch cheats on in the pause menu: Extras > Cheats.\n" > "$PKG/cheats/README.txt"
cp dist/overlays-README.txt "$PKG/overlays/README.txt"
printf "Patches for GBA DS (.ips, .ups, .bps: romhacks, colour patches, translations), in a folder for each game,\nnamed after the game and its region (for example \"Mario & Luigi - Superstar Saga (USA)\"). GBA DS makes a game's folder\nthe first time you play it; your ROM itself is never changed. Switch patches on in the pause menu: Extras > Patches.\n" > "$PKG/patches/README.txt"
cp README.md "$PKG/README.md"
# mGBA is statically linked (MPL-2.0): ship its licence and where to get its source
mkdir -p "$PKG/licenses"
cp LICENSE "$PKG/licenses/GBA-DS-LICENSE.txt"
cp "$DEPS/mgba/LICENSE" "$PKG/licenses/mGBA-LICENSE.txt"
cp assets/fonts/Jost-OFL.txt "$PKG/licenses/Jost-OFL.txt"
cp third_party/rcheevos/LICENSE "$PKG/licenses/rcheevos-LICENSE.txt"
cp third_party/libwebp/COPYING "$PKG/licenses/libwebp-COPYING.txt"
cp third_party/libwebp/PATENTS "$PKG/licenses/libwebp-PATENTS.txt"
printf "GBA DS %s is free software under the GNU General Public License, version 3 only (GBA-DS-LICENSE.txt).\nIt statically links libmgba (c) Jeffrey Pfau, MPL-2.0.\nmGBA source: https://github.com/mgba-emu/mgba (commit %s)\nIts text is set in Jost (c) The Jost Project Authors, SIL Open Font License 1.1 (Jost-OFL.txt).\nRetroAchievements support: rcheevos (c) RetroAchievements, MIT (rcheevos-LICENSE.txt), %s.\nWebP images: libwebp (c) Google Inc., BSD 3-clause (libwebp-COPYING.txt, libwebp-PATENTS.txt), v1.6.0.\nGBA DS source: https://github.com/kyannon/gba-ds (the muOS external core: https://github.com/fragilesilver/gba-ds)\n" "$VERSION" "$MGBA_COMMIT" "$(tail -1 third_party/rcheevos/VERSION)" > "$PKG/licenses/README.txt"
chmod +x "$PKG"/*.sh "$PKG/gba-ds"
mkdir -p dist
rm -f "$ROOT"/dist/gba-ds-external-core-v*-muos.muxapp
(cd "$ROOT/build/pkg-muos" && zip -qr "$ROOT/dist/$ARCHIVE" "$APP")
echo "built dist/$ARCHIVE"
