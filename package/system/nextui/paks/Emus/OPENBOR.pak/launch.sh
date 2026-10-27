#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
# Player 1 defaults are the virtual xb360 pad. A saved file in
# OPENBOR_SAVES_DIR still overrides those defaults.
if [ -z "${USERDATA_PATH:-}" ] || [ -z "${SAVES_PATH:-}" ]; then
	echo "openbor: storage paths are not set" >&2
	exit 1
fi
state="$USERDATA_PATH/OpenBOR"
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG" \
	"$state/Paks" "$state/ScreenShots"
if [ -n "${ZLYME_PAK_LOG:-}" ]; then
	logs="${LOGS_PATH:-/storage/.logs/paks}/$EMU_TAG"
else
	logs=/tmp/zlyme-openbor/Logs
fi
mkdir -p "$logs"
# Previous run's native logs only. Saves and screenshots are other
# directories. A file OpenBOR still has open is not trimmed here:
# this runs before exec, after the previous process has exited.
if [ -n "${ZLYME_PAK_LOG:-}" ]; then
	for _ob in "$logs"/*; do
		[ -f "$_ob" ] || continue
		[ ! -L "$_ob" ] || continue
		_obsz=$(wc -c < "$_ob" 2>/dev/null) || continue
		_obsz=$(printf '%s\n' "$_obsz" | tr -d ' ')
		if [ "$_obsz" -gt 1048576 ]; then
			_obtmp=$(mktemp "${_ob}.trim.XXXXXX") || continue
			if tail -c 1048576 "$_ob" > "$_obtmp"; then
				mv -f "$_obtmp" "$_ob"
			else
				rm -f "$_obtmp"
			fi
		fi
	done
	unset _ob _obsz _obtmp
fi
export OPENBOR_PAKS_DIR="$state/Paks"
export OPENBOR_SAVES_DIR="$SAVES_PATH/$EMU_TAG"
export OPENBOR_LOGS_DIR="$logs"
export OPENBOR_SCREENSHOTS_DIR="$state/ScreenShots"
HOME="$USERDATA_PATH"
cd "$state" || exit 1
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
exec OpenBOR "$ROM"
