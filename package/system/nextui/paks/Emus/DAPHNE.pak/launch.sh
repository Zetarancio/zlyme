#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
export HYPSEUS_SINGE="${HYPSEUS_SINGE:-/usr/share/hypseus-singe}"
if [ -d "$HYPSEUS_SINGE" ]; then
	cd "$HYPSEUS_SINGE" || cd "$HOME"
else
	cd "$HOME"
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
dir=$(dirname "$ROM")
base=$(basename "$ROM")
name=${base%.*}
case "$ROM" in
	*.txt|*.TXT|*.daphne|*.DAPHNE|*.singe|*.SINGE)
		exec hypseus "$name" vldp -framefile "$ROM" -fullscreen -gamepad
		;;
esac
if [ -f "$dir/$name.txt" ]; then
	exec hypseus "$name" vldp -framefile "$dir/$name.txt" -fullscreen -gamepad
fi
exec hypseus "$name" vldp -framefile "$ROM" -fullscreen -gamepad
