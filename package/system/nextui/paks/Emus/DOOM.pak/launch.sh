#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"

root=${ZLYME_STATE_ROOT:-/storage}
cfg=$root/.config/gzdoom

if [ "${ZLYME_DOOM_DRY:-}" = 1 ]; then
	printf 'home=%s\n' "$root"
	printf 'config=%s\n' "$cfg"
	exit 0
fi

mkdir -p "$cfg/cache" "$cfg/soundfonts" "$cfg/fm_banks" "$cfg/screenshots" \
	"$SAVES_PATH/DOOM"
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
HOME=$root
export HOME
cd "$HOME" || exit 1
case "$ROM" in
	*.wad|*.WAD|*.pk3|*.PK3) exec gzdoom +set use_joystick true \
		+set menu_confirm Joy1 +set menu_back Joy2 \
		-savedir "$SAVES_PATH/DOOM" -iwad "$ROM" ;;
	*) exec gzdoom +set use_joystick true \
		+set menu_confirm Joy1 +set menu_back Joy2 \
		-savedir "$SAVES_PATH/DOOM" "$ROM" ;;
esac
