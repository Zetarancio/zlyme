#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"

root=${ZLYME_STATE_ROOT:-/storage}
cfg=$root/.config/gzdoom
mig=${ZLYME_MIGRATE_SH:-/usr/share/nextui/bin/zlyme-migrate-tree.sh}
if [ ! -r "$mig" ]; then
	_pak=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
	mig=$_pak/../../../zlyme/zlyme-migrate-tree.sh
fi
# shellcheck disable=SC1090
[ -r "$mig" ] && . "$mig"
if command -v zlyme_migrate_tree >/dev/null 2>&1; then
	zlyme_migrate_tree "$root/.config/nextui/shared/configs/gzdoom" "$cfg" || true
	zlyme_migrate_tree "$root/.userdata/shared/configs/gzdoom" "$cfg" || true
	zlyme_migrate_tree "$root/.config/nextui/shared/cache/gzdoom" "$cfg/cache" || true
	if [ -n "${SAVES_PATH:-}" ]; then
		zlyme_migrate_tree "$root/.config/nextui/shared/saves/gzdoom" "$SAVES_PATH/DOOM" || true
	fi
	rmdir "$root/.userdata/shared/configs" "$root/.userdata/shared" \
		"$root/.userdata" 2>/dev/null || true
fi

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
	*.wad|*.WAD|*.pk3|*.PK3) exec gzdoom +set use_joystick true -savedir "$SAVES_PATH/DOOM" -iwad "$ROM" ;;
	*) exec gzdoom +set use_joystick true -savedir "$SAVES_PATH/DOOM" "$ROM" ;;
esac
