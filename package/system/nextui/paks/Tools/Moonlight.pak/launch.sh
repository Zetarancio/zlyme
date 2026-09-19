#!/bin/sh
# UI from https://github.com/richieszemeredi/nextui-moonlight-pak (v0.1.0).
# Streams with this image's /usr/bin/moonlight (moonlight-embedded).

APP_BIN="moonlight-pak"
PAK_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAK_NAME=$(basename "$PAK_DIR")
PAK_NAME=${PAK_NAME%.pak}
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

cd "$PAK_DIR" || exit 1
chmod +x "$PAK_DIR/$APP_BIN" 2>/dev/null || true

if [ -n "${SHARED_USERDATA_PATH:-}" ]; then
	SHARED_USERDATA_ROOT="$SHARED_USERDATA_PATH"
elif [ -d "/mnt/SDCARD/.config/nextui/shared" ] || [ -d "/mnt/SDCARD" ]; then
	SHARED_USERDATA_ROOT="/mnt/SDCARD/.config/nextui/shared"
else
	SHARED_USERDATA_ROOT="${HOME:-/tmp}/.config/nextui/shared"
fi
LOG_ROOT=${LOGS_PATH:-"$SHARED_USERDATA_ROOT/logs"}
mkdir -p "$LOG_ROOT"
LOG_FILE="$LOG_ROOT/$APP_BIN.txt"
: >"$LOG_FILE"
exec >>"$LOG_FILE"
exec 2>&1

echo "=== Launching $PAK_NAME ($APP_BIN) at $(date) ==="
echo "platform=${PLATFORM:-unknown} device=${DEVICE:-unknown}"

export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_GAMECONTROLLERCONFIG_FILE="${SDL_GAMECONTROLLERCONFIG_FILE:-/usr/lib/gamecontrollerdb.txt}"
export PATH="/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/storage/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/storage/.config}"

if [ ! -e "./$APP_BIN" ]; then
	echo "missing $APP_BIN"
	command -v show.elf >/dev/null 2>&1 && show.elf "Moonlight UI missing" 3
	exit 1
fi

# Prebuilt Apostrophe still looks at ./font.ttf and .system, not /usr/share/nextui.
# Tools live on exFAT, so a symlink is not allowed — copy the file.
if [ -f /usr/share/nextui/res/font1.ttf ]; then
	mkdir -p "$PAK_DIR/res"
	cp -f /usr/share/nextui/res/font1.ttf "$PAK_DIR/font.ttf"
	cp -f /usr/share/nextui/res/font1.ttf "$PAK_DIR/res/font.ttf"
fi
if [ ! -e /usr/bin/moonlight ]; then
	echo "missing /usr/bin/moonlight"
	command -v show.elf >/dev/null 2>&1 && show.elf "Moonlight is not installed" 3
	exit 1
fi

echo 1 >/tmp/stay_awake
sleep 0.4
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec "./$APP_BIN" "$@"
