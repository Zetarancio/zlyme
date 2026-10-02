#!/bin/sh
APP_BIN=${ZLYME_ZCRAPEGOAT_BIN:-/usr/lib/zlyme/zcrapegoat/zcrapegoat}
PAK_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAK_NAME=$(basename "$PAK_DIR")
PAK_NAME=${PAK_NAME%.pak}
# Pak logging is the shared Zlyme helper. Do not open another log from this script.
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

cd "$PAK_DIR" || exit 1

catalog=$PAK_DIR/resources/systems.json
if [ ! -r "$catalog" ]; then
	echo "ZcrapeGoat catalog missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "ZcrapeGoat catalog missing" 3
	exit 1
fi
export SCRAPEGOAT_SYSTEMS_JSON=$catalog

if [ ! -e "$APP_BIN" ]; then
	echo "ZcrapeGoat missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "ZcrapeGoat is not installed" 3
	exit 1
fi

chmod +x "$APP_BIN" 2>/dev/null || true
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

if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
	export GIT_SSL_CAINFO="$SSL_CERT_FILE"
elif [ -f "$PAK_DIR/lib/cacert.pem" ]; then
	export SSL_CERT_FILE="$PAK_DIR/lib/cacert.pem"
	export GIT_SSL_CAINFO="$SSL_CERT_FILE"
fi

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
	export XDG_RUNTIME_DIR=/tmp/runtime-root
	mkdir -p "$XDG_RUNTIME_DIR"
fi

# Apostrophe still looks at ./font.ttf. Tools live on exFAT, so copy the file.
if [ -f /usr/share/nextui/res/font1.ttf ]; then
	mkdir -p "$PAK_DIR/res"
	cp -f /usr/share/nextui/res/font1.ttf "$PAK_DIR/font.ttf"
	cp -f /usr/share/nextui/res/font1.ttf "$PAK_DIR/res/font.ttf"
fi

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
sleep 0.4
"$APP_BIN" "$@"
st=$?
if [ "$st" -ne 0 ]; then
	echo "exit $st" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "ZcrapeGoat failed ($st)" 3
fi
exit "$st"
