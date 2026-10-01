#!/bin/sh
# Cheat Downloader v1.6.0. Uses the image minui-list and minui-presenter.
# Each system folder is one symlink. When two libraries share a system,
# only that folder's immediate children are linked. Later libraries win
# a duplicate name. Nested game folders stay as directory symlinks.
# OverlayFS cannot use the exFAT OS card, so it is not the view.
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
	# Tests keep the view so list-dirs can read the same symlink tree.
	if [ "${ZLYME_CHEAT_KEEP:-}" = 1 ]; then
		printf 'union=%s\n' "$union"
	else
		rm -rf "$union"
	fi
	rm -f "$mark"
}
trap cleanup EXIT

# Expand a system that already came from another library. One level only.
link_children() {
	_csrc=$1
	_cdest=$2
	for _cf in "$_csrc"/* "$_csrc"/.[!.]* "$_csrc"/..?*; do
		[ -e "$_cf" ] || [ -L "$_cf" ] || continue
		_cbase=$(basename "$_cf")
		case "$_cbase" in
			.|..) continue ;;
		esac
		ln -sfn "$_cf" "$_cdest/$_cbase"
	done
}

place_system() {
	_psrc=$1
	_pname=$2
	_pdest=$union/$_pname
	if [ ! -e "$_pdest" ] && [ ! -L "$_pdest" ]; then
		ln -s "$_psrc" "$_pdest"
		return 0
	fi
	if [ -L "$_pdest" ]; then
		_pprev=$(readlink "$_pdest")
		rm -f "$_pdest"
		mkdir -p "$_pdest"
		link_children "$_pprev" "$_pdest"
	fi
	link_children "$_psrc" "$_pdest"
}

libs=${ZLYME_LIBRARIES_FILE:-/run/zlyme/libraries}
if [ -r "$libs" ]; then
	while IFS= read -r lib || [ -n "$lib" ]; do
		[ -n "$lib" ] || continue
		for base in "$lib/Roms" "$lib/roms" "$lib/ROMS"; do
			[ -d "$base" ] || continue
			for d in "$base"/*; do
				[ -d "$d" ] || continue
				place_system "$d" "$(basename "$d")"
			done
			break
		done
	done < "$libs"
else
	base=$SDCARD_PATH/Roms
	if [ -d "$base" ]; then
		for d in "$base"/*; do
			[ -d "$d" ] || continue
			place_system "$d" "$(basename "$d")"
		done
	fi
fi

export ROM_DIR=$union
export CHEAT_DIR=${CHEATS_PATH:-$SDCARD_PATH/Cheats}
export CACHE_DIR=$SDCARD_PATH/.config/cheat-downloader
mkdir -p "$CHEAT_DIR" "$CACHE_DIR"
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
