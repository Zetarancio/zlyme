#!/bin/sh
# PPSSPP 1.19 SDL has no --memstick. Config is $XDG_CONFIG_HOME/ppsspp
# (Knulli). Passing --memstick made PPSSPP treat the config dir as a ROM.
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
SDCARD_PATH="${SDCARD_PATH:-/storage}"
USERDATA_PATH="${USERDATA_PATH:-$SDCARD_PATH/.config/nextui/${PLATFORM:-my355}}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD_PATH/.config}"
export USERDATA_PATH XDG_CONFIG_HOME
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
export HOME
# The stock ini is also copied by zlyme-stock-seed. An existing ini stays.
SEED=/usr/share/zlyme/emu-defaults/ppsspp.ini
INI="$XDG_CONFIG_HOME/ppsspp/PSP/SYSTEM/ppsspp.ini"
mkdir -p "$XDG_CONFIG_HOME/ppsspp/PSP/SYSTEM" \
	"$SAVES_PATH/PSP/SAVEDATA" "$SAVES_PATH/PSP/PPSSPP_STATE" \
	"$XDG_CONFIG_HOME/ppsspp/PSP/SAVEDATA" "$XDG_CONFIG_HOME/ppsspp/PSP/PPSSPP_STATE"
if [ -f "$SEED" ] && [ ! -s "$INI" ]; then
	cp "$SEED" "$INI"
fi
# exec replaces this shell, so an EXIT trap would not run. pak-launch
# is outside the pak session and unmounts only the paths recorded here,
# after a normal exit and after MENU+START. A destination that is already
# mounted is not mounted again.
ppsspp_mounted() {
	if command -v mountpoint >/dev/null 2>&1; then
		mountpoint -q "$1"
		return $?
	fi
	awk -v p="$1" '$2 == p { found = 1 } END { exit found ? 0 : 1 }' /proc/mounts
}
ppsspp_record=${ZLYME_PPSSPP_BINDS:-/tmp/zlyme-ppsspp-binds}
ppsspp_new=$(mktemp "${TMPDIR:-/tmp}/zlyme-ppsspp-binds.XXXXXX") || ppsspp_new=
if [ -n "$ppsspp_new" ]; then
	ppsspp_owned=0
	for ppsspp_pair in \
		"$SAVES_PATH/PSP/SAVEDATA|$XDG_CONFIG_HOME/ppsspp/PSP/SAVEDATA" \
		"$SAVES_PATH/PSP/PPSSPP_STATE|$XDG_CONFIG_HOME/ppsspp/PSP/PPSSPP_STATE"
	do
		ppsspp_src=${ppsspp_pair%%|*}
		ppsspp_dst=${ppsspp_pair#*|}
		if ppsspp_mounted "$ppsspp_dst"; then
			printf '%s\n' "$ppsspp_dst" >> "$ppsspp_new"
			ppsspp_owned=1
		elif [ -d "$ppsspp_src" ] && mount --bind "$ppsspp_src" "$ppsspp_dst"; then
			printf '%s\n' "$ppsspp_dst" >> "$ppsspp_new"
			ppsspp_owned=1
		fi
	done
	if [ "$ppsspp_owned" = 1 ]; then
		mv "$ppsspp_new" "$ppsspp_record"
	else
		rm -f "$ppsspp_new"
	fi
fi
unset ppsspp_record ppsspp_new ppsspp_owned ppsspp_pair ppsspp_src ppsspp_dst
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
# Assets live next to this prefix; cwd USERDATA_PATH has none.
if [ -d /usr/share/ppsspp/assets ]; then
	cd /usr/share/ppsspp || true
fi
# 0 is OpenGL. 3 is Vulkan. Both use the SDL KMSDRM window.
# Vulkan then creates a VK_KHR_display surface. The ini stays the
# user's; this only records which path was selected.
ppsspp_vk=0
if [ -f "$INI" ] && grep -q '^GraphicsBackend *= *3' "$INI"; then
	ppsspp_vk=1
fi
if [ "$ppsspp_vk" -eq 1 ]; then
	if [ -e /usr/share/vulkan/icd.d/mali_icd.json ] || \
		[ -n "${VK_ICD_FILENAMES:-}" ]; then
		echo "ppsspp: Vulkan via VK_KHR_display" >&2
	else
		echo "ppsspp: Vulkan selected but no ICD; OpenGL display path" >&2
	fi
fi
exec PPSSPPSDL --fullscreen --dpi 0.5 "$ROM"
