#!/bin/sh
msg() {
	echo "$1"
	if command -v show.elf >/dev/null 2>&1; then
		show.elf "$1" 3
	else
		sleep 2
	fi
}
if [ ! -x /usr/bin/vtree ]; then
	msg "vtree is not installed"
	exit 1
fi
# Squashfs /usr/share/vtree is read-only. Run from userdata so ActiveTheme
# is Zlyme even if an older image still has Dark in the packaged ini.
RUN=/storage/.userdata/shared/vtree
mkdir -p "$RUN/theme"
cp -a /usr/share/vtree/config.ini "$RUN/config.ini"
cp -a /usr/share/vtree/theme.ini "$RUN/theme.ini" 2>/dev/null || true
if [ -d /usr/share/vtree/theme ]; then
	cp -a /usr/share/vtree/theme/. "$RUN/theme/" 2>/dev/null || true
fi
if [ -f /usr/share/vtree/theme/Zlyme.ini ]; then
	cp -a /usr/share/vtree/theme/Zlyme.ini "$RUN/theme/Zlyme.ini"
fi
ln -sfn /usr/share/vtree/res "$RUN/res"
ln -sfn /usr/share/vtree/fonts "$RUN/fonts"
if grep -q '^ActiveTheme=' "$RUN/config.ini"; then
	sed -i 's|^ActiveTheme=.*|ActiveTheme=Zlyme|' "$RUN/config.ini"
else
	printf '%s\n' '[ActiveTheme]' 'ActiveTheme=Zlyme' >> "$RUN/config.ini"
fi
sleep 0.4
cd "$RUN" || exit 1
exec /usr/share/vtree/vtree
