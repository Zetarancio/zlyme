#!/bin/sh
# Tools → RetroArch with no ROM. ra-run keeps the SDL mapping, the GPU
# environment, DRM release, audio, and the system log. Quitting
# RetroArch returns to NextUI the same way a game launch does.
# Comment out to skip this pak's log (About → System logs).
# shellcheck disable=SC1091
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
if command -v zlyme-governor >/dev/null 2>&1; then
	zlyme-governor play >/dev/null 2>&1 || true
fi
exec ra-run
