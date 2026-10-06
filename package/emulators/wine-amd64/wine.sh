#!/bin/sh
# Kron4ek Wine 11.6 amd64-wow64. The loader is a 64-bit ELF. 32-bit PE
# builtins live in i386-windows/. Unix libs on LD_LIBRARY_PATH stay
# x86_64. box64 does not load the i386 unix objects as host libraries.
# Wine respawns itself via WINELOADER and wineserver via WINESERVER;
# those must be these wrappers, not the raw x86_64 ELFs.
# A WoW64 prefix is win64 and still runs 32-bit PE.
WINE_ROOT=/usr/lib/wine-amd64
REAL="$WINE_ROOT/bin/wine"
export BOX64_LD_LIBRARY_PATH="/usr/share/box64/lib${BOX64_LD_LIBRARY_PATH:+:$BOX64_LD_LIBRARY_PATH}"
dll="$WINE_ROOT/lib/wine"
if [ -d "$WINE_ROOT/lib/wine/x86_64-windows" ]; then
	dll="$WINE_ROOT/lib/wine/x86_64-windows:$WINE_ROOT/lib/wine/x86_64-unix:$dll"
fi
if [ -d "$WINE_ROOT/lib/wine/i386-windows" ]; then
	dll="$WINE_ROOT/lib/wine/i386-windows:$dll"
fi
if [ -d "$WINE_ROOT/lib/wine/i386-unix" ]; then
	dll="$WINE_ROOT/lib/wine/i386-unix:$dll"
fi
export WINEDLLPATH="$dll"
if [ -d "$WINE_ROOT/lib/wine/x86_64-unix" ]; then
	export LD_LIBRARY_PATH="$WINE_ROOT/lib/wine/x86_64-unix${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
export WINEARCH="${WINEARCH:-win64}"
export WINELOADER=/usr/bin/wine
export WINESERVER=/usr/bin/wineserver
mkdir -p "${WINEPREFIX:-$HOME/.wine}"
exec box64 "$REAL" "$@"
