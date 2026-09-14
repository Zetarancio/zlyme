#!/bin/sh
# NextUI PICO-8 pak. Binary is user-supplied pico8_64 (Lexaloffle).
# A cart named Splore launches pico8 -splore (same as ROCKNIX / minui-pico-8-pak).
PAK_DIR="$(dirname "$0")"
EMU_TAG=$(basename "$PAK_DIR" .pak)
ROM="$1"
SDCARD_PATH="${SDCARD_PATH:-/storage}"
SHARED_USERDATA_PATH="${SHARED_USERDATA_PATH:-$SDCARD_PATH/.userdata/shared}"
USERDATA_PATH="${USERDATA_PATH:-$SDCARD_PATH/.userdata/${PLATFORM:-my355}}"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG" \
	"$USERDATA_PATH/Pico-8-native" "$SHARED_USERDATA_PATH/Pico-8-native"

seed_splore() {
	romdir=""
	if [ -n "$ROM" ] && [ -f "$ROM" ]; then
		romdir=$(dirname "$ROM")
	fi
	[ -d "$romdir" ] || romdir="$SDCARD_PATH/Roms/Pico-8 (PICO)"
	mkdir -p "$romdir"

	marker="$SHARED_USERDATA_PATH/Pico-8-native/splore-installed"
	[ -f "$marker" ] && return 0

	src="$PAK_DIR/splore/Splore.p8.png"
	[ -f "$src" ] || return 0

	for e in "$romdir"/*; do
		[ -f "$e" ] || continue
		case "$(basename "$e")" in
			*[Ss]plore*) mkdir -p "$(dirname "$marker")"; : >"$marker"; return 0 ;;
		esac
	done

	cp -f "$src" "$romdir/Splore.p8"
	mkdir -p "$romdir/.media"
	[ -f "$romdir/.media/Splore.png" ] || cp -f "$src" "$romdir/.media/Splore.png"
	mkdir -p "$(dirname "$marker")"
	: >"$marker"
	sync
}

seed_splore
# pico8 wrapper sets -home. Do not point HOME at the parent userdata dir.
export HOME="${SHARED_USERDATA_PATH}/Pico-8-native"
mkdir -p "$HOME/carts"
cd "$HOME"
exec pico8 "$ROM"
