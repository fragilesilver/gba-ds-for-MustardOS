# The aarch64 cross-build's dependencies, shared by build-rocknix.sh and
# build-muos.sh (sourced, from the repository's root, with ROOT and DEPS set
# and scripts/mgba-options.sh loaded): a GCC aarch64 toolchain (or
# AARCH64_TOOLCHAIN_BIN), libmgba in deps/mgba/build-aarch64 and SDL2 (only to
# link against: the device's own libSDL2 is used at runtime) in
# deps/sdl-aarch64. Sets CROSS and MGBA_BUILD_DIR.
# AARCH64_CPU (default cortex-a55, ROCKNIX's RK3568): what libmgba is built
# for; another CPU gets a build folder of its own (build-aarch64-<cpu>).
AARCH64_CPU="${AARCH64_CPU:-cortex-a55}"
export AARCH64_CPU
if [ "$AARCH64_CPU" = cortex-a55 ]; then MGBA_BUILD_DIR="$DEPS/mgba/build-aarch64"; else MGBA_BUILD_DIR="$DEPS/mgba/build-aarch64-$AARCH64_CPU"; fi

# --- toolchain -------------------------------------------------------------
if [ -z "${AARCH64_TOOLCHAIN_BIN:-}" ]; then
	TC="$DEPS/aarch64-linux-gnu"
	if [ ! -x "$TC/bin/aarch64-linux-gnu-gcc" ]; then
		git clone --depth 1 https://github.com/radcolor/aarch64-linux-gnu "$TC"
		# The prebuilt toolchain's linker scripts hard-code its CI build path.
		for f in "$TC"/aarch64-linux-gnu/lib/*.so; do
			grep -q /home/runner "$f" 2>/dev/null &&
				sed -i "s|/home/runner/work/build-tools-gcc/build-tools-gcc/aarch64-linux-gnu/aarch64-linux-gnu/lib/|$TC/aarch64-linux-gnu/lib/|g" "$f"
		done
		# ...and its limits.h doesn't chain to glibc's (PATH_MAX etc. missing).
		L=$(echo "$TC"/lib/gcc/aarch64-linux-gnu/*/include-fixed/limits.h)
		if ! grep -qE "gbadual|gba-ds" "$L"; then  # already patched (by either name)
			{ printf '/* gba-ds: chain to glibc limits.h */\n#ifndef _GCC_LIMITS_H_\n#define _GCC_LIMITS_H_\n#include_next <limits.h>\n#endif\n'; cat "$L"; } > "$L.tmp" && mv "$L.tmp" "$L"
		fi
	fi
	export AARCH64_TOOLCHAIN_BIN="$TC/bin"
fi
CROSS="$AARCH64_TOOLCHAIN_BIN/aarch64-linux-gnu-"

# --- libmgba ---------------------------------------------------------------
if [ ! -d "$DEPS/mgba" ]; then
	git clone https://github.com/mgba-emu/mgba.git "$DEPS/mgba"
	git -C "$DEPS/mgba" checkout "$MGBA_COMMIT"
fi
# a build dir configured the old way (LIBMGBA_ONLY) is started over
if grep -q "^LIBMGBA_ONLY:UNINITIALIZED=ON" "$MGBA_BUILD_DIR/CMakeCache.txt" 2>/dev/null; then
	rm -rf "${MGBA_BUILD_DIR:?}"
fi
cmake -S "$DEPS/mgba" -B "$MGBA_BUILD_DIR" -DCMAKE_TOOLCHAIN_FILE="$ROOT/cmake/aarch64.cmake" "${MGBA_OPTS[@]}"
make -C "$MGBA_BUILD_DIR" -j"$(nproc)" mgba zlibstatic

# --- SDL2 (only to link against; the device's own libSDL2 is used at runtime) ---
if [ ! -d "$DEPS/SDL2" ]; then
	git clone --depth 1 -b "$SDL_BRANCH" https://github.com/libsdl-org/SDL.git "$DEPS/SDL2"
fi
cmake -S "$DEPS/SDL2" -B "$DEPS/SDL2/build-aarch64" -DCMAKE_TOOLCHAIN_FILE="$ROOT/cmake/aarch64.cmake" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS/sdl-aarch64" -DSDL_STATIC=OFF -DSDL_TEST=OFF
make -C "$DEPS/SDL2/build-aarch64" -j"$(nproc)" install
