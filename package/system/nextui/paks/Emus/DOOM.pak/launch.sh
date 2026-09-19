#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
# gzdoom was patched for MinUI .userdata; NextUI shared is .config/nextui.
shared="${SHARED_USERDATA_PATH:-/storage/.config/nextui/shared}"
mkdir -p "$shared/configs/gzdoom" "$shared/saves/gzdoom" "$shared/cache/gzdoom" \
	/mnt/SDCARD/.userdata/shared/configs/gzdoom
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
HOME="$USERDATA_PATH"
cd "$HOME"
case "$ROM" in
	*.wad|*.WAD|*.pk3|*.PK3) exec gzdoom -iwad "$ROM" ;;
	*) exec gzdoom "$ROM" ;;
esac
