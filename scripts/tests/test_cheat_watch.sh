#!/bin/sh
# Cheat Downloader must start the same way with pak logging on or off.
# The presenter marker is the handshake. The pak log is not.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
launch=$ROOT/package/system/nextui/paks/Tools/Cheat\ Downloader.pak/launch.sh
wrap=$ROOT/package/system/nextui/paks/Tools/Cheat\ Downloader.pak/minui-presenter
if grep -q 'ZLYME_PAK_LOG' "$launch"; then
	echo "cheat launcher still consults the pak log" >&2
	exit 1
fi
if grep -E -q 'arg=25|arg=45' "$wrap"; then
	echo "presenter wrapper still rewrites timeouts" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/card/Roms/Empty"
printf '%s\n' "$work/card" > "$work/libs"

cat > "$work/presenter" << 'EOF'
#!/bin/sh
mark=${ZLYME_CHEAT_PRESENTER_MARK:-}
if [ -z "$mark" ] || [ ! -f "$mark" ]; then
	echo "presenter marker missing before exec" >&2
	exit 3
fi
printf '%s\n' "$*" >> "$PRESENTER_ARGS"
exit 0
EOF
cat > "$work/app-ok" << EOF
#!/bin/sh
"$work/presenter-wrap" --message "Checking for updates..." --timeout -1
"$work/presenter-wrap" --message "Download the cheat database?" --timeout 0
sleep 1
echo done > "$work/done"
exit 0
EOF
cat > "$work/app-hang" << EOF
#!/bin/sh
sleep 5
echo done > "$work/done"
exit 0
EOF
cp "$wrap" "$work/presenter-wrap"
chmod 0755 "$work/presenter" "$work/app-ok" "$work/app-hang" "$work/presenter-wrap"

marks() {
	find /tmp -name 'zlyme-cheat-presenter.*' -o -name '.zlyme-cheat-presenter.*' 2>/dev/null | sort
}

run_ok() {
	logmode=$1
	rm -f "$work/done" "$work/args"
	: > "$work/args"
	: > "$work/paklog"
	set --
	if [ "$logmode" = log ]; then
		set -- env ZLYME_PAK_LOG=$work/paklog
	fi
	"$@" env \
		ZLYME_CHEAT_BIN=$work/app-ok \
		ZLYME_CHEAT_WATCH_SEC=4 \
		ZLYME_PRESENTER=$work/presenter \
		PRESENTER_ARGS=$work/args \
		ZLYME_LIBRARIES_FILE=$work/libs \
		SDCARD_PATH=$work/card \
		ZLYME_MIGRATE_SH=/dev/null \
		"$launch"
	test -f "$work/done"
	grep -F -q -- '--message Checking for updates... --timeout -1' "$work/args"
	grep -F -q -- '--message Download the cheat database? --timeout 0' "$work/args"
	if grep -E -q -- '--timeout (25|45)' "$work/args"; then
		echo "launcher path rewrote a presenter timeout ($logmode)" >&2
		exit 1
	fi
	if [ -n "$(marks)" ]; then
		echo "presenter marker left behind ($logmode)" >&2
		marks >&2
		exit 1
	fi
}

run_hang() {
	logmode=$1
	rm -f "$work/done"
	: > "$work/paklog"
	if [ "$logmode" = seeded ]; then
		printf '%s\n' 'cheat: presenter Checking for updates...' > "$work/paklog"
	fi
	set --
	if [ "$logmode" != off ]; then
		set -- env ZLYME_PAK_LOG=$work/paklog
	fi
	if "$@" env \
		ZLYME_CHEAT_BIN=$work/app-hang \
		ZLYME_CHEAT_WATCH_SEC=2 \
		ZLYME_LIBRARIES_FILE=$work/libs \
		SDCARD_PATH=$work/card \
		ZLYME_MIGRATE_SH=/dev/null \
		"$launch"
	then
		echo "hang without a presenter was treated as success ($logmode)" >&2
		exit 1
	fi
	test ! -f "$work/done"
	if [ -n "$(marks)" ]; then
		echo "presenter marker left behind after hang ($logmode)" >&2
		exit 1
	fi
}

run_ok off
run_ok log
run_hang off
run_hang log
run_hang seeded
echo "cheat watch ok"
