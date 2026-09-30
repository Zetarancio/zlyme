#!/bin/sh
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh
msg() {
	echo "$1"
	if command -v show.elf >/dev/null 2>&1; then
		show.elf "$1" 3
	else
		sleep 2
	fi
}

# Immutable defaults live under SHARE. RUN is the user's copy.
# ZLYME_VTREE_SHARE, ZLYME_VTREE_RUN, and ZLYME_VTREE_TEST=1 are test seams.
SHARE=${ZLYME_VTREE_SHARE:-/usr/share/vtree}
RUN=${ZLYME_VTREE_RUN:-/storage/.config/nextui/shared/vtree}
MARKER=$RUN/.zlyme-vtree-v1

set_ini() {
	file=$1
	key=$2
	val=$3
	if grep -q "^${key}=" "$file"; then
		sed -i "s|^${key}=.*|${key}=${val}|" "$file"
	else
		printf '%s\n' "${key}=${val}" >> "$file"
	fi
}

seed_vtree() {
	mkdir -p "$RUN/theme"
	if [ ! -f "$RUN/config.ini" ]; then
		cp -a "$SHARE/config.ini" "$RUN/config.ini"
		set_ini "$RUN/config.ini" ShowHidden true
		set_ini "$RUN/config.ini" ActiveTheme Zlyme
		: > "$MARKER"
	elif [ ! -f "$MARKER" ]; then
		# Older Files.pak replaced this file every launch, so a saved
		# ShowHidden=false was the packaged default, not a user choice.
		set_ini "$RUN/config.ini" ShowHidden true
		: > "$MARKER"
	fi
	if [ ! -f "$RUN/theme.ini" ] && [ -f "$SHARE/theme.ini" ]; then
		cp -a "$SHARE/theme.ini" "$RUN/theme.ini"
	fi
	if [ -d "$SHARE/theme" ] && [ ! -d "$RUN/theme" ]; then
		mkdir -p "$RUN/theme"
		cp -a "$SHARE/theme/." "$RUN/theme/"
	fi
	if [ -f "$SHARE/theme/Zlyme.ini" ] && [ ! -f "$RUN/theme/Zlyme.ini" ]; then
		mkdir -p "$RUN/theme"
		cp -a "$SHARE/theme/Zlyme.ini" "$RUN/theme/Zlyme.ini"
	fi
	if [ -e "$SHARE/res" ]; then
		ln -sfn "$SHARE/res" "$RUN/res"
	fi
	if [ -e "$SHARE/fonts" ]; then
		ln -sfn "$SHARE/fonts" "$RUN/fonts"
	fi
}

if [ "${ZLYME_VTREE_TEST:-}" = 1 ]; then
	seed_vtree
	exit 0
fi

if [ ! -x /usr/bin/vtree ] && [ ! -x "$SHARE/vtree" ]; then
	msg "vtree is not installed"
	exit 1
fi
seed_vtree
sleep 0.4
cd "$RUN" || exit 1
command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true
if [ -x "$SHARE/vtree" ]; then
	exec "$SHARE/vtree"
fi
exec /usr/share/vtree/vtree
