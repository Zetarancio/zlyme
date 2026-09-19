#!/bin/sh
# Kron4ek Wine 10+ keeps unix ntdll in x86_64-unix/, PE builtins in
# x86_64-windows/. ntdll.so needs the x86_64 libgcc box64 ships.
# Wine respawns itself via WINELOADER and wineserver via WINESERVER;
# those must be these wrappers, not the raw x86_64 ELFs.
WINE_ROOT=/usr/lib/wine-amd64
REAL="$WINE_ROOT/bin/wine"
export BOX64_LD_LIBRARY_PATH="/usr/share/box64/lib${BOX64_LD_LIBRARY_PATH:+:$BOX64_LD_LIBRARY_PATH}"
if [ -d "$WINE_ROOT/lib/wine/x86_64-unix" ]; then
	export WINEDLLPATH="$WINE_ROOT/lib/wine/x86_64-windows:$WINE_ROOT/lib/wine/x86_64-unix:$WINE_ROOT/lib/wine"
	export LD_LIBRARY_PATH="$WINE_ROOT/lib/wine/x86_64-unix${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
	export WINEDLLPATH="$WINE_ROOT/lib/wine"
fi
export WINEARCH="${WINEARCH:-win64}"
export WINELOADER=/usr/bin/wine
export WINESERVER=/usr/bin/wineserver
mkdir -p "${WINEPREFIX:-$HOME/.wine}"
exec box64 "$REAL" "$@"
