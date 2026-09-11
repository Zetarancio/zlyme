#!/bin/sh
export WINELOADER=/usr/lib/wine-amd64/bin/wine
export WINESERVER=/usr/lib/wine-amd64/bin/wineserver
export WINEDLLPATH=/usr/lib/wine-amd64/lib/wine
exec box64 /usr/lib/wine-amd64/bin/wine "$@"
