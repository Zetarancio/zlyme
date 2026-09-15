#!/bin/sh
APP_BIN="scrapegoat"
PAK_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAK_NAME=$(basename "$PAK_DIR")
PAK_NAME=${PAK_NAME%.pak}

cd "$PAK_DIR" || exit 1

chmod +x "$PAK_DIR/$APP_BIN" 2>/dev/null || true
chmod +x "$PAK_DIR/resources/bin/"* 2>/dev/null || true

export SDCARD_PATH="${SDCARD_PATH:-/storage}"
export PLATFORM="${PLATFORM:-my355}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_RENDER_DRIVER="${SDL_RENDER_DRIVER:-opengles2}"
export SDL_GAMECONTROLLERCONFIG_FILE="${SDL_GAMECONTROLLERCONFIG_FILE:-/usr/lib/gamecontrollerdb.txt}"
export LD_LIBRARY_PATH="/usr/lib:${LD_LIBRARY_PATH:-}"
mkdir -p /mnt
if [ ! -e /mnt/SDCARD ]; then
	ln -sfn "$SDCARD_PATH" /mnt/SDCARD
fi

export PATH="$PAK_DIR/resources/bin:$PATH"
export GIT_EXEC_PATH="$PAK_DIR/resources/bin"

if [ -f "$PAK_DIR/lib/cacert.pem" ]; then
	export SSL_CERT_FILE="$PAK_DIR/lib/cacert.pem"
	export GIT_SSL_CAINFO="$SSL_CERT_FILE"
fi

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
	export XDG_RUNTIME_DIR=/tmp/runtime-root
	mkdir -p "$XDG_RUNTIME_DIR"
fi

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

if [ ! -e "./$APP_BIN" ]; then
	echo "missing $APP_BIN"
	command -v show.elf >/dev/null 2>&1 && show.elf "ScrapeGoat missing" 3
	exit 1
fi

sleep 0.4
./"$APP_BIN" "$@"
st=$?
if [ "$st" -ne 0 ]; then
	echo "exit $st"
	command -v show.elf >/dev/null 2>&1 && show.elf "ScrapeGoat failed ($st)" 3
fi
exit "$st"
