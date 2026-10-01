#!/bin/sh
# Phase 9 state paths. Pre-release trees are not migrated.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
if [ -e "$ROOT/package/system/nextui/zlyme/zlyme-migrate-tree.sh" ]; then
	echo "migrate helper is still in the tree" >&2
	exit 1
fi
if grep -R -n 'zlyme_migrate_tree' "$ROOT/package" "$ROOT/board" >/dev/null; then
	echo "a production file still calls the migrate helper" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Ruffle keeps the SWF in Roms and names companion data under Saves.
lib=$work/card
mkdir -p "$lib/Roms/Flash (FLASH)" "$lib/flash_data/storage"
printf 'swf' > "$lib/Roms/Flash (FLASH)/Game.swf"
printf 'progress' > "$lib/flash_data/storage/game"
printf '%s\n' "$lib" > "$work/libs"
out=$(ZLYME_RUFFLE_DRY=1 ZLYME_STATE_ROOT=$work/os \
	ZLYME_LIBRARY_SH=$ROOT/package/system/nextui/zlyme/zlyme-library.sh \
	ZLYME_LIBRARIES_FILE=$work/libs \
	ROM="$lib/Roms/Flash (FLASH)/Game.swf" \
	"$ROOT/package/system/nextui/paks/Emus/FLASH.pak/launch.sh" \
	"$lib/Roms/Flash (FLASH)/Game.swf")
printf '%s\n' "$out" | grep -F -q "data=$lib/Saves/FLASH/flash_data"
printf '%s\n' "$out" | grep -F -q "romroot=$lib"
printf '%s\n' "$out" | grep -F -q "flash=$lib/Roms/Flash (FLASH)"
test -f "$lib/Roms/Flash (FLASH)/Game.swf"
test -f "$lib/flash_data/storage/game"
test ! -d "$lib/Saves/FLASH/flash"
grep -q 'RUFFLE_DATA_DIR' \
	"$ROOT/package/system/ruffle-handheld/0001-save-under-data-dir.patch"

# Music state is the config directory. auto_update is forced off.
out=$(ZLYME_MUSIC_DRY=1 ZLYME_STATE_ROOT=$work/music \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh")
printf '%s\n' "$out" | grep -F -q "state=$work/music/.config/music-player"
grep -q '^auto_update=0$' "$work/music/.config/music-player/settings.cfg"
test ! -d "$work/music/.userdata"
grep -q 'bestaudio\[ext=m4a\]/bestaudio' \
	"$ROOT/package/system/music-player/0002-audio-fallback-and-silent-cfg.patch"
grep -q '/dev/null' \
	"$ROOT/package/system/music-player/0002-audio-fallback-and-silent-cfg.patch"
grep -q 'auto_update=0' \
	"$ROOT/package/system/nextui/paks/Tools/Music Player.pak/launch.sh"

# GZDoom config follows HOME and does not hardcode a card path.
mkdir -p "$work/doom/Saves"
out=$(ZLYME_DOOM_DRY=1 ZLYME_STATE_ROOT=$work/doom \
	BIOS_PATH=$work/doom/Bios SAVES_PATH=$work/doom/Saves \
	"$ROOT/package/system/nextui/paks/Emus/DOOM.pak/launch.sh" "$work/doom/game.wad")
printf '%s\n' "$out" | grep -F -q "home=$work/doom"
printf '%s\n' "$out" | grep -F -q "config=$work/doom/.config/gzdoom"
grep -q 'menu_confirm Joy1' \
	"$ROOT/package/system/nextui/paks/Emus/DOOM.pak/launch.sh"
grep -q 'menu_back Joy2' \
	"$ROOT/package/system/nextui/paks/Emus/DOOM.pak/launch.sh"
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
out=$(ZLYME_PRESENTER=$fake \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/minui-presenter" \
	--message "Download the cheat database?" --timeout 0)
printf '%s\n' "$out" | grep -F -q -- '--timeout 0'
if grep -q 'mount -t overlay' \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh"
then
	echo "cheat launcher uses overlay despite exFAT" >&2
	exit 1
fi
grep -q 'place_system' \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh"

echo "persist paths ok"
