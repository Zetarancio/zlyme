#!/bin/sh
EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
mkdir -p "$BIOS_PATH/$EMU_TAG" "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
SEED=
for s in /usr/share/zlyme/emu-defaults/flycast/emu.cfg /storage/.config/zlyme/emu-defaults/flycast/emu.cfg; do
	[ -f "$s" ] && SEED=$s && break
done
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/flycast/emu.cfg"
if [ -n "$SEED" ] && [ ! -e "$CFG" ]; then
	mkdir -p "$(dirname "$CFG")"
	cp "$SEED" "$CFG"
fi
# The earlier Zlyme seed wrote these two keys, but Flycast uses SDL
# instance IDs for them, not stable joystick positions. Let its startup
# index order select ports. Preserve all other saved settings.
if [ -f "$CFG" ] && grep -Eq '^maple_sdl_joystick_[01] = [01]$' "$CFG"; then
	sed -i \
		-e '/^maple_sdl_joystick_0 = 0$/d' \
		-e '/^maple_sdl_joystick_1 = 1$/d' "$CFG"
fi
# Add Flycast's own resume keys when they are absent. An explicit yes
# or no stays. The temp file is in the cfg directory: that file is on
# exFAT, and a cross-filesystem mv can drop the original.
fly_ensure_resume() {
	_cfg=$1
	[ -f "$_cfg" ] || return 0
	_need_save=0
	_need_load=0
	grep -q '^Dreamcast.AutoSaveState =' "$_cfg" || _need_save=1
	grep -q '^Dreamcast.AutoLoadState =' "$_cfg" || _need_load=1
	if [ "$_need_save" = 0 ] && [ "$_need_load" = 0 ]; then
		return 0
	fi
	_dir=$(dirname "$_cfg")
	_tmp=$(mktemp "$_dir/emu.cfg.XXXXXX") || return 0
	_wrote=0
	while IFS= read -r _line || [ -n "$_line" ]; do
		printf '%s\n' "$_line"
		if [ "$_line" = "[config]" ] && [ "$_wrote" = 0 ]; then
			if [ "$_need_save" = 1 ]; then
				printf '%s\n' 'Dreamcast.AutoSaveState = yes'
			fi
			if [ "$_need_load" = 1 ]; then
				printf '%s\n' 'Dreamcast.AutoLoadState = yes'
			fi
			_wrote=1
		fi
	done < "$_cfg" > "$_tmp"
	if [ "$_wrote" = 0 ]; then
		printf '%s\n' '[config]' >> "$_tmp"
		if [ "$_need_save" = 1 ]; then
			printf '%s\n' 'Dreamcast.AutoSaveState = yes' >> "$_tmp"
		fi
		if [ "$_need_load" = 1 ]; then
			printf '%s\n' 'Dreamcast.AutoLoadState = yes' >> "$_tmp"
		fi
	fi
	if [ ! -s "$_tmp" ]; then
		rm -f "$_tmp"
		return 0
	fi
	grep -q '^Dreamcast.AutoSaveState =' "$_tmp" || { rm -f "$_tmp"; return 0; }
	grep -q '^Dreamcast.AutoLoadState =' "$_tmp" || { rm -f "$_tmp"; return 0; }
	while IFS= read -r _line || [ -n "$_line" ]; do
		[ -n "$_line" ] || continue
		grep -qxF "$_line" "$_tmp" || { rm -f "$_tmp"; return 0; }
	done < "$_cfg"
	if sync -f "$_tmp" 2>/dev/null; then
		:
	else
		sync 2>/dev/null || true
	fi
	if ! mv -f "$_tmp" "$_cfg"; then
		rm -f "$_tmp"
	fi
}
fly_ensure_resume "$CFG"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$SAVES_PATH/$EMU_TAG" "$XDG_DATA_HOME/flycast"
for f in dc_boot.bin dc_flash.bin; do
	for src in "$BIOS_PATH/DC/$f" "$BIOS_PATH/$f"; do
		[ -f "$src" ] || continue
		[ -e "$SAVES_PATH/$EMU_TAG/$f" ] || ln -s "$src" "$SAVES_PATH/$EMU_TAG/$f" 2>/dev/null || cp -n "$src" "$SAVES_PATH/$EMU_TAG/$f" 2>/dev/null || true
		break
	done
done
# exec replaces this shell, so an EXIT trap would not run. The bind
# stays up while Flycast exits, which is when it writes its autosave.
# pak-launch is outside the process group and unmounts the recorded
# path after wait, including when MENU+START has killed the group.
if [ -d "$SAVES_PATH/$EMU_TAG" ]; then
	if mount --bind "$SAVES_PATH/$EMU_TAG" "$XDG_DATA_HOME/flycast"; then
		_fly_bind=/tmp/zlyme-flycast-bind
		rm -f "$_fly_bind"
		printf '%s\n' "$XDG_DATA_HOME/flycast" > "$_fly_bind"
		unset _fly_bind
	fi
fi
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu "$EMU_TAG" >/dev/null 2>&1 || true
command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
if command -v zlyme-audio >/dev/null 2>&1; then
	eval "$(zlyme-audio export 2>/dev/null)" || true
fi
exec flycast "$ROM"
