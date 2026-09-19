#!/bin/sh
export BOX64_LD_LIBRARY_PATH="/usr/share/box64/lib${BOX64_LD_LIBRARY_PATH:+:$BOX64_LD_LIBRARY_PATH}"
exec box64 /usr/lib/wine-amd64/bin/wineserver "$@"
