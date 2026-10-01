#!/bin/sh
# NextUI PICO-8 pak. Binary is user-supplied pico8_64 (Lexaloffle).
# A cart named Splore launches pico8 -splore (same as ROCKNIX / minui-pico-8-pak).
PAK_DIR="$(dirname "$0")"
EMU_TAG=$(basename "$PAK_DIR" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
SDCARD_PATH="${SDCARD_PATH:-/storage}"
SHARED_USERDATA_PATH="${SHARED_USERDATA_PATH:-$SDCARD_PATH/.config/nextui/shared}"
USERDATA_PATH="${USERDATA_PATH:-$SDCARD_PATH/.config/nextui/${PLATFORM:-my355}}"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG" \
	"$USERDATA_PATH/Pico-8-native" "$SHARED_USERDATA_PATH/Pico-8-native"

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
if [ "${ZLYME_EMU_CORE:-}" = fake08 ]; then
	exec ra-run -L "${CORES_PATH:-/usr/lib/libretro}/fake08_libretro.so" "$ROM"
fi
# pico8 wrapper sets -home. Do not point HOME at the parent userdata dir.
export HOME="${SHARED_USERDATA_PATH}/Pico-8-native"
mkdir -p "$HOME/carts" "$HOME/cdata" "$HOME/bbs" "$HOME/config" "$HOME/data"
export XDG_CONFIG_HOME="$HOME/config"
export XDG_DATA_HOME="$HOME/data"
cd "$HOME"
pico8 "$ROM"
st=$?
# Titles are indexed after PICO exits, not while the list is drawing.
if [ -x /usr/sbin/zlyme-pico-bbs ]; then
	/usr/sbin/zlyme-pico-bbs || true
fi
exit "$st"
