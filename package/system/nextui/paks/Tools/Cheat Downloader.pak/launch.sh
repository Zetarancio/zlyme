#!/bin/sh
# Cheat Downloader v1.6.0. Uses the image minui-list and minui-presenter.
# ROM folders from every mounted library are linked, not copied.
# The cheat database is downloaded only when this pak runs.
PAK_DIR="$(dirname "$0")"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

APP=${ZLYME_CHEAT_BIN:-/usr/lib/zlyme/cheat-downloader/cheat_manager}
SDCARD_PATH="${SDCARD_PATH:-/storage}"

if [ "${ZLYME_CHEAT_DRY:-}" != 1 ] && [ ! -x "$APP" ]; then
	echo "cheat-downloader: missing" >&2
	command -v show.elf >/dev/null 2>&1 && show.elf "Cheat Downloader is not installed" 3
	exit 1
fi

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true

union=$(mktemp -d /tmp/zlyme-cheat-roms.XXXXXX)
mark=/tmp/zlyme-cheat-presenter.$$
rm -f "$mark"
export ZLYME_CHEAT_PRESENTER_MARK=$mark
cleanup() {
	rm -rf "$union"
	rm -f "$mark"
}
trap cleanup EXIT

merge_dir() {
	src=$1
	dest=$2
	if [ ! -e "$dest" ]; then
		ln -s "$src" "$dest"
		return 0
	fi
	if [ -L "$dest" ]; then
		prev=$(readlink "$dest")
		rm -f "$dest"
		mkdir -p "$dest"
		merge_dir "$prev" "$dest"
		src=$1
		dest=$2
	fi
	for f in "$src"/*; do
		[ -e "$f" ] || continue
		base=$(basename "$f")
		if [ -d "$f" ] && [ ! -L "$f" ]; then
			if [ -L "$dest/$base" ]; then
				merge_dir "$f" "$dest/$base"
			else
				mkdir -p "$dest/$base"
				merge_dir "$f" "$dest/$base"
			fi
		else
			ln -sfn "$f" "$dest/$base"
		fi
	done
}

libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
if [ -r "$libs" ]; then
	while IFS= read -r lib || [ -n "$lib" ]; do
		[ -n "$lib" ] || continue
		for base in "$lib/Roms" "$lib/roms" "$lib/ROMS"; do
			[ -d "$base" ] || continue
			for d in "$base"/*; do
				[ -d "$d" ] || continue
				merge_dir "$d" "$union/$(basename "$d")"
			done
		done
	done < "$libs"
else
	base=$SDCARD_PATH/Roms
	if [ -d "$base" ]; then
		for d in "$base"/*; do
			[ -d "$d" ] || continue
			merge_dir "$d" "$union/$(basename "$d")"
		done
	fi
fi

export ROM_DIR=$union
export CHEAT_DIR=${CHEATS_PATH:-$SDCARD_PATH/Cheats}
export CACHE_DIR=$SDCARD_PATH/.config/cheat-downloader
mkdir -p "$CHEAT_DIR" "$CACHE_DIR"
mig=${ZLYME_MIGRATE_SH:-/usr/share/nextui/bin/zlyme-migrate-tree.sh}
if [ ! -r "$mig" ]; then
	_pak=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
	mig=$_pak/../../../zlyme/zlyme-migrate-tree.sh
fi
# shellcheck disable=SC1090
[ -r "$mig" ] && . "$mig"
if command -v zlyme_migrate_tree >/dev/null 2>&1; then
	zlyme_migrate_tree "$SDCARD_PATH/.config/zlyme/cheat-downloader" "$CACHE_DIR" || true
fi
echo "cheat: FIND_LOCAL_DB"
echo "cheat: CHECK_UPDATE"
export PATH="$PAK_DIR:${PATH:-}"
export HOME=${HOME:-$SDCARD_PATH/.config/nextui/my355}
if [ "${ZLYME_CHEAT_DRY:-}" = 1 ]; then
	find "$union" -type l | sort | while IFS= read -r link; do
		printf '%s %s\n' "$(basename "$(dirname "$link")")/$(basename "$link")" "$(readlink "$link")"
	done
	printf 'cache=%s\n' "$CACHE_DIR"
	exit 0
fi
# The menu is experimental. If the presenter never starts, leave instead
# of holding a black panel. The marker is created by this pak's presenter
# wrapper. Pak logging is optional and is not part of the handshake.
# MENU+START is the escape when a screen is up. Presenter timeouts are
# left as the application set them.
"$APP" &
child=$!
seen=0
i=0
watch=${ZLYME_CHEAT_WATCH_SEC:-20}
case $watch in
	''|*[!0-9]*) watch=20 ;;
esac
while [ "$i" -lt "$watch" ]; do
	if [ -f "$mark" ]; then
		seen=1
		break
	fi
	kill -0 "$child" 2>/dev/null || break
	i=$((i + 1))
	sleep 1
done
if [ "$seen" -eq 0 ] && kill -0 "$child" 2>/dev/null; then
	kill "$child" 2>/dev/null || true
	wait "$child" 2>/dev/null || true
	echo "cheat: no presenter; exiting" >&2
	command -v show.elf >/dev/null 2>&1 &&
		show.elf "Cheat Downloader could not open its menu" 4
	exit 1
fi
wait "$child"
exit $?
