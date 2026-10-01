#!/bin/sh
# Persistent-state moves: library flash_data, music config, gzdoom config.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Rename when the destination is absent, including a name with a space.
mkdir -p "$work/legacy/flash_data/storage/Mario ATV"
printf 'save' > "$work/legacy/flash_data/storage/Mario ATV/keep"
# shellcheck disable=SC1091
. "$ROOT/package/system/nextui/zlyme/zlyme-migrate-tree.sh"
zlyme_migrate_tree "$work/legacy/flash_data" "$work/legacy/Saves/FLASH/flash_data"
test -f "$work/legacy/Saves/FLASH/flash_data/storage/Mario ATV/keep"
test ! -d "$work/legacy/flash_data"

# Do not overwrite a different destination file. Leave the source.
mkdir -p "$work/both/src" "$work/both/dst"
printf 'old' > "$work/both/src/note"
printf 'new' > "$work/both/dst/note"
printf 'onlysrc' > "$work/both/src/extra"
if zlyme_migrate_tree "$work/both/src" "$work/both/dst"; then
	echo "conflict was ignored" >&2
	exit 1
fi
test "$(cat "$work/both/dst/note")" = new
test -f "$work/both/src/note"
test -f "$work/both/dst/extra"
test ! -f "$work/both/src/extra"

# Identical files are not a conflict.
mkdir -p "$work/same/src" "$work/same/dst"
printf 'same' > "$work/same/src/note"
printf 'same' > "$work/same/dst/note"
zlyme_migrate_tree "$work/same/src" "$work/same/dst"
test ! -d "$work/same/src"

# Ruffle launch selects the SWF library and migrates its top-level flash_data.
lib=$work/card
mkdir -p "$lib/Roms/Flash (FLASH)" "$lib/flash_data/storage"
printf 'swf' > "$lib/Roms/Flash (FLASH)/Game.swf"
printf 'progress' > "$lib/flash_data/storage/game"
printf '%s\n' "$lib" > "$work/libs"
mkdir -p "$lib/.config/zlyme/ruffle/data" "$lib/.config/zlyme/ruffle/flash"
printf 'companion' > "$lib/.config/zlyme/ruffle/data/keep"
printf 'not-a-rom' > "$lib/.config/zlyme/ruffle/flash/leave"
mkdir -p "$work/os/.config/zlyme/ruffle/logs"
printf 'oldlog' > "$work/os/.config/zlyme/ruffle/logs/session"
out=$(ZLYME_RUFFLE_DRY=1 ZLYME_STATE_ROOT=$work/os \
	ZLYME_LIBRARY_SH=$ROOT/package/system/nextui/zlyme/zlyme-library.sh \
	ZLYME_LIBRARIES_FILE=$work/libs \
	ZLYME_MIGRATE_SH=$ROOT/package/system/nextui/zlyme/zlyme-migrate-tree.sh \
	ROM=$lib/Roms/Flash\ \(FLASH\)/Game.swf \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh" \
	"$lib/Roms/Flash (FLASH)/Game.swf")
printf '%s\n' "$out" | grep -F -q "data=$lib/Saves/FLASH/flash_data"
printf '%s\n' "$out" | grep -F -q "romroot=$lib"
printf '%s\n' "$out" | grep -F -q "flash=$lib/Roms/Flash (FLASH)"
printf '%s\n' "$out" | grep -F -q "rom=$lib/Roms/Flash (FLASH)/Game.swf"
test -f "$lib/Roms/Flash (FLASH)/Game.swf"
test -f "$lib/Saves/FLASH/flash_data/storage/game"
test -f "$lib/Saves/FLASH/flash_data/keep"
test ! -d "$lib/flash_data"
test ! -d "$lib/.config/zlyme/ruffle/data"
test -f "$lib/.config/zlyme/ruffle/flash/leave"
test ! -d "$lib/Saves/FLASH/flash"
test -f "$work/os/.config/ruffle/logs/session"
test ! -d "$work/os/.config/zlyme/ruffle/logs"

# Music state leaves .userdata and the old NextUI shared tree.
mkdir -p "$work/music/.userdata/shared/music-player/radio"
printf 'auto_update=1\nvolume=40\n' > "$work/music/.userdata/shared/music-player/settings.cfg"
printf 'station\n' > "$work/music/.userdata/shared/music-player/radio/stations.txt"
mkdir -p "$work/music/.config/nextui/shared/music-player"
printf 'from-shared\n' > "$work/music/.config/nextui/shared/music-player/resume.cfg"
out=$(ZLYME_MUSIC_DRY=1 ZLYME_STATE_ROOT=$work/music \
	ZLYME_MIGRATE_SH=$ROOT/package/system/nextui/zlyme/zlyme-migrate-tree.sh \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh")
printf '%s\n' "$out" | grep -F -q "state=$work/music/.config/music-player"
test -f "$work/music/.config/music-player/radio/stations.txt"
test -f "$work/music/.config/music-player/resume.cfg"
grep -q '^auto_update=0$' "$work/music/.config/music-player/settings.cfg"
grep -q '^volume=40$' "$work/music/.config/music-player/settings.cfg"
test ! -d "$work/music/.userdata"
# A second launch must not recreate .userdata.
ZLYME_MUSIC_DRY=1 ZLYME_STATE_ROOT=$work/music \
	ZLYME_MIGRATE_SH=$ROOT/package/system/nextui/zlyme/zlyme-migrate-tree.sh \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh" >/dev/null
test ! -d "$work/music/.userdata"

# GZDoom config follows HOME=/storage/.config/gzdoom and does not touch .userdata.
mkdir -p "$work/doom/.config/nextui/shared/configs/gzdoom"
printf 'old-ini\n' > "$work/doom/.config/nextui/shared/configs/gzdoom/gzdoom.ini"
mkdir -p "$work/doom/.userdata/shared/configs/gzdoom"
printf 'legacy\n' > "$work/doom/.userdata/shared/configs/gzdoom/autoexec.cfg"
mkdir -p "$work/doom/Saves"
out=$(ZLYME_DOOM_DRY=1 ZLYME_STATE_ROOT=$work/doom \
	BIOS_PATH=$work/doom/Bios SAVES_PATH=$work/doom/Saves \
	ZLYME_MIGRATE_SH=$ROOT/package/system/nextui/zlyme/zlyme-migrate-tree.sh \
	"$ROOT/package/system/nextui/paks/Emus/DOOM.pak/launch.sh" "$work/doom/game.wad")
printf '%s\n' "$out" | grep -F -q "home=$work/doom"
printf '%s\n' "$out" | grep -F -q "config=$work/doom/.config/gzdoom"
test -f "$work/doom/.config/gzdoom/gzdoom.ini"
test -f "$work/doom/.config/gzdoom/autoexec.cfg"
test ! -d "$work/doom/.userdata"
grep -q '.config/gzdoom/gzdoom.ini' \
	"$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh"
if grep -q '/mnt/SDCARD' "$ROOT/package/emulators/gzdoom/0001-Fix-file-paths.patch"; then
	echo "gzdoom patch still hardcodes a card path" >&2
	exit 1
fi

# Presenter timeouts stay as the application passed them.
fake=$work/presenter
cat > "$fake" << 'EOF'
#!/bin/sh
printf '%s\n' "$*"
EOF
chmod +x "$fake"
out=$(ZLYME_PRESENTER=$fake \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/minui-presenter" \
	--message "Checking for updates..." --timeout -1)
printf '%s\n' "$out" | grep -F -q -- '--timeout -1'
if printf '%s\n' "$out" | grep -F -q -- '--timeout 25'; then
	echo "startup presenter timeout was rewritten" >&2
	exit 1
fi
out=$(ZLYME_PRESENTER=$fake \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/minui-presenter" \
	--message "Download the cheat database?" --timeout 0)
printf '%s\n' "$out" | grep -F -q -- '--timeout 0'
if printf '%s\n' "$out" | grep -F -q -- '--timeout 45'; then
	echo "confirmation timeout was rewritten" >&2
	exit 1
fi
out=$(ZLYME_PRESENTER=$fake \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/minui-presenter" \
	--message "Downloading database..." --timeout -1)
printf '%s\n' "$out" | grep -F -q -- '--timeout -1'
if printf '%s\n' "$out" | grep -E -q -- '--timeout (25|45)'; then
	echo "download presenter timeout was rewritten" >&2
	exit 1
fi

# Music sources no longer point helper installs at the pak or a relative CA.
grep -q '/etc/ssl/certs/ca-certificates.crt' \
	"$ROOT/package/system/music-player/0001-zlyme-state-and-ca.patch"
grep -q '/storage/.config/music-player/helpers/yt-dlp' \
	"$ROOT/package/system/music-player/0001-zlyme-state-and-ca.patch"
if grep -E -q 'mkdir[^#]*\.userdata' \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Emus/DOOM.pak/launch.sh" \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh"
then
	echo "a launcher still creates .userdata" >&2
	exit 1
fi

echo "persist paths ok"
