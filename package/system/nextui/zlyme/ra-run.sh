#!/bin/sh
# NextUI sets HOME to userdata and XDG_CONFIG_HOME to /storage/.config.
# RetroArch then creates an empty retroarch.cfg that drops /etc hotkeys
# and looks for BIOS under ~/.config/retroarch/system.
CFGDIR=/storage/.config/retroarch
CFG=$CFGDIR/retroarch.cfg
ETC=/etc/retroarch.cfg
mkdir -p "$CFGDIR"
if [ ! -s "$CFG" ]; then
	rm -f "$CFG"
	[ -f "$ETC" ] && cp "$ETC" "$CFG"
fi
# MENU (button 10) exits, matching NextUI. Select opens the RA menu.
exec retroarch --appendconfig "$ETC" "$@"
