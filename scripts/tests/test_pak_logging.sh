#!/bin/sh
# Stock PAK logs follow pak-log.sh. Logging off creates no diagnostic file.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PAK=$ROOT/package/system/nextui/zlyme/pak-log.sh
RA=$ROOT/package/system/nextui/zlyme/ra-run.sh
EMUS=$ROOT/package/system/nextui/paks/Emus
TOOLS=$ROOT/package/system/nextui/paks/Tools

fail() {
	echo "pak logging: $*" >&2
	exit 1
}

work=$(mktemp -d)
last=/tmp/last.txt
ra_cfg=/tmp/zlyme-minui-ra.cfg
if [ -e "$last" ]; then
	cp -a "$last" "$work/last-save"
fi
if [ -e "$ra_cfg" ]; then
	cp -a "$ra_cfg" "$work/ra-cfg-save"
fi
restore() {
	if [ -e "$work/last-save" ]; then
		cp -a "$work/last-save" "$last"
	else
		rm -f "$last"
	fi
	if [ -e "$work/ra-cfg-save" ]; then
		cp -a "$work/ra-cfg-save" "$ra_cfg"
	else
		rm -f "$ra_cfg"
	fi
	rm -rf "$work"
}
trap restore EXIT

mkdir -p "$work/bin"
export PATH="$work/bin:/usr/bin:/bin"

# Every stock launcher uses the shared helper and does not open its own log.
found=0
for tree in "$EMUS" "$TOOLS"; do
	for f in "$tree"/*/*.pak/launch.sh "$tree"/*.pak/launch.sh; do
		[ -f "$f" ] || continue
		found=$((found + 1))
		grep -q 'pak-log.sh' "$f" || fail "$f does not source pak-log.sh"
		if grep -n -E 'exec >>|LOG_FILE=|^set -x$' "$f"; then
			fail "$f opens its own diagnostic log"
		fi
	done
done
[ "$found" -gt 10 ] || fail "only found $found stock launchers"

# Tool (no EMU_EXE): logging on captures stdout. Logging off does not.
on=$work/on
off=$work/off
sh -c '
	EMU_TAG=Moonlight ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$1
	. "$2"
	echo captured-stdout
' sh "$on" "$PAK" > "$work/tool-on.out"
grep -q 'captured-stdout' "$on/paks/Moonlight.log" || fail "tool stdout was not logged"
[ ! -s "$work/tool-on.out" ] || fail "tool stdout escaped the pak log"
sh -c '
	EMU_TAG=GB EMU_EXE=gambatte ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$1
	. "$2"
	echo core-stdout
' sh "$on" "$PAK" > "$work/core-on.out"
grep -q '=== GB' "$on/paks/GB.log" || fail "core header missing"
grep -q 'core-stdout' "$work/core-on.out" || fail "core stdout was swallowed"
[ -n "${ZLYME_PAK_LOG:-}" ] && fail "pak log variable leaked" || true
sh -c '
	EMU_TAG=Moonlight ZLYME_LOG_ROOT=$1
	. "$2"
	echo visible
' sh "$off" "$PAK" > "$work/off.out"
grep -q visible "$work/off.out" || fail "logging off hid stdout"
[ ! -e "$off/paks/Moonlight.log" ] || fail "logging off created a pak log"
[ ! -d "$off/paks" ] || fail "logging off created the pak log directory"

# Three generations, then a fourth launch drops the oldest.
rot=$work/rot
i=1
while [ "$i" -le 4 ]; do
	sh -c '
		EMU_TAG=GBA EMU_EXE=core ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$1
		. "$2"
		echo "LAUNCH $3" >> "$ZLYME_PAK_LOG"
	' sh "$rot" "$PAK" "$i" >/dev/null
	i=$((i + 1))
done
grep -q 'LAUNCH 4' "$rot/paks/GBA.log"
grep -q 'LAUNCH 3' "$rot/paks/GBA.log.1"
grep -q 'LAUNCH 2' "$rot/paks/GBA.log.2"
[ ! -e "$rot/paks/GBA.log.3" ] || fail "a fourth generation was kept"

copy_launch() {
	src=$1
	dest_dir=$2
	mkdir -p "$dest_dir"
	sed "s|/usr/share/nextui/bin/pak-log.sh|$PAK|g" "$src" > "$dest_dir/launch.sh"
	chmod 0755 "$dest_dir/launch.sh"
}

# Emulator: off creates nothing; on rotates and tells ra-run the log path.
cat > "$work/bin/ra-run" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$OUT/args"
printf '%s\n' "${ZLYME_PAK_LOG:-}" > "$OUT/paklog"
exit 0
EOF
cat > "$work/bin/show.elf" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$OUT/show"
exit 0
EOF
chmod 0755 "$work/bin/ra-run" "$work/bin/show.elf"

gb=$work/GB.pak
copy_launch "$EMUS/GB.pak/launch.sh" "$gb"
mkdir -p "$work/bios" "$work/saves" "$work/home" "$work/card-logs"
q=$(printf '\047')
run_gb() {
	OUT=$1
	mkdir -p "$OUT"
	export OUT
	if [ "${3:-}" = 1 ]; then
		ZLYME_LOG_FORCE=1
		export ZLYME_LOG_FORCE
	else
		unset ZLYME_LOG_FORCE
	fi
	BIOS_PATH=$work/bios SAVES_PATH=$work/saves USERDATA_PATH=$work/home \
		HOME=$work/home CORES_PATH=$work/cores \
		ZLYME_LOG_ROOT=$2 \
		sh "$gb/launch.sh" "/r/it${q}s game.gb"
	unset ZLYME_LOG_FORCE
}
run_gb "$work/gb-off" "$work/gb-off-logs"
[ ! -e "$work/gb-off-logs/paks/GB.log" ] || fail "GB logging off created a log"
grep -q "it's game.gb" "$work/gb-off/args" || fail "GB dropped the rom when logging was off"
[ -z "$(cat "$work/gb-off/paklog")" ] || fail "GB set a pak log while logging was off"
i=1
while [ "$i" -le 4 ]; do
	run_gb "$work/gb-on" "$work/gb-on-logs" 1
	i=$((i + 1))
done
[ -s "$work/gb-on/paklog" ] || fail "GB did not pass the pak log to ra-run"
grep -q '=== GB' "$work/gb-on-logs/paks/GB.log"
[ -f "$work/gb-on-logs/paks/GB.log.2" ] || fail "GB did not rotate"
[ ! -e "$work/gb-on-logs/paks/GB.log.3" ] || fail "GB kept a fourth log"

# RetroArch verbose log follows the pak log, and the manual debug file stays on tmpfs.
mkdir -p "$work/xdg/retroarch" "$work/bios" "$work/shared"
: > "$work/bios/.zlyme-ready"
cat > "$work/bin/retroarch" << 'EOF'
#!/bin/sh
i=1
for a in "$@"; do
	printf '%s\n' "$a" >> "$OUT/ra-args"
	i=$((i + 1))
done
exit 0
EOF
chmod 0755 "$work/bin/retroarch"
ra_call() {
	OUT=$1
	mode=$2
	mkdir -p "$OUT"
	export OUT
	unset ZLYME_PAK_LOG ZLYME_RA_DEBUG
	case "$mode" in
		pak) ZLYME_PAK_LOG=$work/gb-on-logs/paks/GB.log ;;
		debug) ZLYME_RA_DEBUG=1 ;;
	esac
	if [ -n "${ZLYME_PAK_LOG:-}" ]; then
		export ZLYME_PAK_LOG
	fi
	if [ -n "${ZLYME_RA_DEBUG:-}" ]; then
		export ZLYME_RA_DEBUG
	fi
	XDG_CONFIG_HOME=$work/xdg BIOS_PATH=$work/bios SAVES_PATH=$work/saves \
		SHARED_USERDATA_PATH=$work/shared \
		HOME=$work/home EMU_TAG=GB ZLYME_RESOLVED_ROM=/r/a.gb \
		LOGS_PATH=$work/card-logs \
		"$RA" -L /cores/gambatte_libretro.so /r/a.gb 2>/dev/null
	unset ZLYME_PAK_LOG ZLYME_RA_DEBUG
}
ra_call "$work/ra-off" off
grep -q -- '--log-file' "$work/ra-off/ra-args" && fail "logging off passed --log-file" || true
[ ! -e "$work/card-logs/ra-debug.log" ] || fail "debug log was written to LOGS_PATH"
ra_call "$work/ra-on" pak
grep -q -- "--log-file=$work/gb-on-logs/paks/GB.log" "$work/ra-on/ra-args" \
	|| grep -q -- '--log-file' "$work/ra-on/ra-args" || fail "pak log was not passed to retroarch"
# --log-file and the path may be one argv or two. Either must name the pak log.
grep -q "$work/gb-on-logs/paks/GB.log" "$work/ra-on/ra-args" || fail "retroarch log path"
ra_call "$work/ra-debug" debug
grep -q '/tmp/ra-debug.log' "$work/ra-debug/ra-args" || fail "manual debug log left tmpfs"
[ ! -e "$work/card-logs/ra-debug.log" ] || fail "manual debug log used LOGS_PATH"

# Moonlight: the old private log is not created or truncated. The UI error still shows.
card=$work/card-logs
mkdir -p "$card"
printf '%s\n' KEEP > "$card/moonlight-pak.txt"
ml=$work/Moonlight.pak
copy_launch "$TOOLS/Moonlight.pak/launch.sh" "$ml"
OUT=$work/ml-off
mkdir -p "$OUT"
export OUT
: > "$OUT/show"
set +e
LOGS_PATH=$card ZLYME_LOG_ROOT=$work/ml-off-logs \
	sh "$ml/launch.sh" > "$OUT/stdout" 2>"$OUT/stderr"
ml_st=$?
set -e
[ "$ml_st" -ne 0 ] || fail "moonlight succeeded without its UI"
grep -q 'Moonlight UI missing' "$OUT/show" || fail "moonlight hid the missing-UI error"
grep -q KEEP "$card/moonlight-pak.txt" || fail "moonlight truncated its old log while logging was off"
[ ! -e "$work/ml-off-logs/paks/Moonlight.log" ] || fail "moonlight created a pak log while logging was off"
OUT=$work/ml-on
mkdir -p "$OUT"
export OUT
: > "$OUT/show"
set +e
LOGS_PATH=$card ZLYME_LOG_ROOT=$work/ml-on-logs ZLYME_LOG_FORCE=1 \
	sh "$ml/launch.sh" > "$OUT/stdout" 2>"$OUT/stderr"
set -e
grep -q 'Moonlight UI missing' "$OUT/show" || fail "moonlight hid the error while logging was on"
grep -q KEEP "$card/moonlight-pak.txt" || fail "moonlight truncated moonlight-pak.txt"
[ -s "$work/ml-on-logs/paks/Moonlight.log" ] || fail "moonlight did not use the pak log"
grep -q 'missing moonlight-pak' "$work/ml-on-logs/paks/Moonlight.log" \
	|| grep -q '=== Moonlight' "$work/ml-on-logs/paks/Moonlight.log" \
	|| fail "moonlight pak log was empty"

# Overlays: no private log, no trace, and the fetch error is still printed.
cat > "$work/bin/curl" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 0755 "$work/bin/curl"
ov=$work/Overlays.pak
copy_launch "$TOOLS/Overlays.pak/launch.sh" "$ov"
sed -i "s|export PATH=\"/usr/bin:|export PATH=\"$work/bin:/usr/bin:|" "$ov/launch.sh"
printf '%s\n' KEEP > "$card/Overlays.txt"
OUT=$work/ov-off
mkdir -p "$OUT" "$work/ov-data" "$work/ov-sd"
export OUT
LOGS_PATH=$card SHARED_USERDATA_PATH=$work/ov-data SDCARD_PATH=$work/ov-sd \
	PLATFORM=my355 DEVICE=my355 ZLYME_LOG_ROOT=$work/ov-off-logs \
	sh "$ov/launch.sh" > "$OUT/stdout" 2>"$OUT/stderr" || true
grep -q 'Could not fetch' "$OUT/stdout" || fail "overlays hid the fetch error"
grep -q KEEP "$card/Overlays.txt" || fail "overlays removed its old log while logging was off"
[ ! -e "$work/ov-off-logs/paks/Overlays.log" ] || fail "overlays created a pak log while logging was off"
if grep -q '^+ ' "$OUT/stdout" "$OUT/stderr"; then
	fail "overlays traced while logging was off"
fi
OUT=$work/ov-on
mkdir -p "$OUT"
export OUT
LOGS_PATH=$card SHARED_USERDATA_PATH=$work/ov-data SDCARD_PATH=$work/ov-sd \
	PLATFORM=my355 DEVICE=my355 ZLYME_LOG_ROOT=$work/ov-on-logs ZLYME_LOG_FORCE=1 \
	sh "$ov/launch.sh" > "$OUT/stdout" 2>"$OUT/stderr" || true
grep -q KEEP "$card/Overlays.txt" || fail "overlays truncated Overlays.txt"
[ -s "$work/ov-on-logs/paks/Overlays.log" ] || fail "overlays did not use the pak log"
grep -q 'Could not fetch' "$work/ov-on-logs/paks/Overlays.log" || fail "overlays log dropped the error"
if grep -q '^+ ' "$work/ov-on-logs/paks/Overlays.log" "$OUT/stdout"; then
	fail "overlays traced while logging was on"
fi

# Settings still reaches settings.elf. Logging off does not create a pak log.
cat > "$work/bin/settings.elf" << 'EOF'
#!/bin/sh
printf '%s\n' ran > "$OUT/settings"
exit 0
EOF
chmod 0755 "$work/bin/settings.elf"
st=$work/Settings.pak
copy_launch "$TOOLS/Settings.pak/launch.sh" "$st"
sed -i "s|/usr/bin/settings.elf|$work/bin/settings.elf|" "$st/launch.sh"
OUT=$work/settings-off
mkdir -p "$OUT"
export OUT
LOGS_PATH=$card ZLYME_LOG_ROOT=$work/settings-off-logs sh "$st/launch.sh"
[ "$(cat "$OUT/settings")" = ran ] || fail "settings did not start"
[ ! -e "$work/settings-off-logs/paks/Settings.log" ] || fail "settings created a log while logging was off"
OUT=$work/settings-on
mkdir -p "$OUT"
export OUT
LOGS_PATH=$card ZLYME_LOG_ROOT=$work/settings-on-logs ZLYME_LOG_FORCE=1 sh "$st/launch.sh"
[ -s "$work/settings-on-logs/paks/Settings.log" ] || fail "settings did not log when logging was on"
[ "$(cat "$OUT/settings")" = ran ] || fail "settings logging blocked the program"

echo "pak logging ok"
