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
export OPENBOR_PAKS_DIR="$state/Paks"
export OPENBOR_SAVES_DIR="$SAVES_PATH/$EMU_TAG"
export OPENBOR_LOGS_DIR="$logs"
export OPENBOR_SCREENSHOTS_DIR="$state/ScreenShots"
HOME="$USERDATA_PATH"
cd "$state" || exit 1
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec OpenBOR "$ROM"
