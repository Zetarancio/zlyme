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
	echo core-stderr >&2
' sh "$on" "$PAK" > "$work/core-on.out" 2>"$work/core-on.err"
grep -q '=== GB' "$on/paks/GB.log" || fail "core header missing"
grep -q 'core-stdout' "$on/paks/GB.log" || fail "core stdout was not logged"
grep -q 'core-stderr' "$on/paks/GB.log" || fail "core stderr was not logged"
[ ! -s "$work/core-on.out" ] || fail "core stdout escaped the pak log"
[ ! -s "$work/core-on.err" ] || fail "core stderr escaped the pak log"
[ -n "${ZLYME_PAK_LOG:-}" ] && fail "pak log variable leaked" || true
printf '%s\n' x > "$work/notdir"
sh -c '
	EMU_TAG=GB EMU_EXE=gambatte ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$1
	. "$2"
	echo survived
' sh "$work/notdir" "$PAK" > "$work/notdir.out" 2>"$work/notdir.err"
grep -q survived "$work/notdir.out" || fail "unwritable log aborted the launch"
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
grep -q -- '--log-file' "$work/ra-on/ra-args" && fail "pak log was passed as --log-file" || true
grep -q -- '^-v$' "$work/ra-on/ra-args" || fail "pak log did not pass -v"
ra_call "$work/ra-debug" debug
grep -q '/tmp/ra-debug.log' "$work/ra-debug/ra-args" || fail "manual debug log left tmpfs"
[ ! -e "$work/card-logs/ra-debug.log" ] || fail "manual debug log used LOGS_PATH"

# RetroArch v1.22.2 opens the first --log-file with "wb". This is that
# open. It is not the RetroArch binary, and it does not claim the binary
# emitted a log line.
trunc=$work/trunc.log
printf '%s\n' '=== header ===' > "$trunc"
python3 -c 'import sys; open(sys.argv[1], "wb").write(b"VERBOSE\n")' "$trunc"
grep -q '=== header ===' "$trunc" && fail "wb open kept the header" || true
grep -q '^VERBOSE$' "$trunc" || fail "wb open did not replace the file"

# The waited launch redirects first, then execs retroarch. A stub that
# would truncate on --log-file must not be given that argument. Its own
# stdout and stderr are the stream under test, not RetroArch's logger.
cat > "$work/bin/retroarch" << 'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$OUT/ra-args"
for a in "$@"; do
	case "$a" in
		--log-file=*)
			python3 -c 'import sys; open(sys.argv[1], "wb").write(b"VERBOSE\n")' "${a#--log-file=}"
			;;
	esac
done
echo core-stdout
echo core-stderr >&2
echo verbose-line
exit "${ZLYME_STUB_RC:-0}"
EOF
chmod 0755 "$work/bin/retroarch"
q=$(printf '\047')
rom="/r/Player${q}s game.gb"
OUT=$work/stream
mkdir -p "$OUT"
export OUT
set +e
ZLYME_STUB_RC=7 ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$work/stream-logs \
	ZLYME_RA_LOG_CFG=$work/stream-logs/ra-log.cfg \
	XDG_CONFIG_HOME=$work/xdg SHARED_USERDATA_PATH=$work/shared \
	BIOS_PATH=$work/bios SAVES_PATH=$work/saves USERDATA_PATH=$work/home \
	HOME=$work/home \
	sh -c '
		EMU_TAG=GB
		EMU_EXE=gambatte
		ROM=$1
		ZLYME_LOG_FORCE=1
		ZLYME_LOG_ROOT=$2
		. "$3"
		exec "$4" -L /cores/gambatte_libretro.so "$1"
	' sh "$rom" "$work/stream-logs" "$PAK" "$RA" \
	> "$OUT/stdout" 2>"$OUT/stderr"
stream_st=$?
set -e
[ "$stream_st" -eq 7 ] || fail "core launch returned $stream_st"
log=$work/stream-logs/paks/GB.log
grep -q '=== GB' "$log" || fail "stream launch lost the header"
grep -q "Player${q}s game.gb" "$log" || fail "stream launch dropped the rom"
grep -q 'core-stdout' "$log" || fail "stream launch missed stdout"
grep -q 'core-stderr' "$log" || fail "stream launch missed stderr"
grep -q 'verbose-line' "$log" || fail "stream launch missed the stub verbose line"
grep -q '^VERBOSE$' "$log" && fail "stream launch truncated the pak log" || true
grep -q -- '--log-file' "$OUT/ra-args" && fail "stream launch passed --log-file" || true
grep -q -- '^-v$' "$OUT/ra-args" || fail "stream launch did not pass -v"
grep -q 'log_to_file = "false"' "$work/stream-logs/ra-log.cfg" \
	|| fail "stream launch did not force log_to_file off"
grep -q "$work/stream-logs/ra-log.cfg" "$OUT/ra-args" \
	|| fail "stream launch did not append the log_to_file session file"
[ ! -s "$OUT/stdout" ] || fail "stream stdout escaped"
[ ! -s "$OUT/stderr" ] || fail "stream stderr escaped"

# Tools → RetroArch, no ROM. Same redirect, no core argument.
# The earlier GB cases stub ra-run. This one must reach retroarch.
cat > "$work/bin/ra-run" << EOF
#!/bin/sh
exec "$RA" "\$@"
EOF
chmod 0755 "$work/bin/ra-run"
ra_tool=$work/RetroArch.pak
copy_launch "$TOOLS/RetroArch.pak/launch.sh" "$ra_tool"
OUT=$work/ra-tool
mkdir -p "$OUT"
export OUT
set +e
ZLYME_STUB_RC=0 ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$work/ra-tool-logs \
	ZLYME_RA_LOG_CFG=$work/ra-tool-logs/ra-log.cfg \
	XDG_CONFIG_HOME=$work/xdg SHARED_USERDATA_PATH=$work/shared \
	BIOS_PATH=$work/bios SAVES_PATH=$work/saves USERDATA_PATH=$work/home \
	HOME=$work/home \
	sh "$ra_tool/launch.sh" > "$OUT/stdout" 2>"$OUT/stderr"
tool_st=$?
set -e
[ "$tool_st" -eq 0 ] || fail "RetroArch tool returned $tool_st"
tlog=$work/ra-tool-logs/paks/RetroArch.log
grep -q '=== RetroArch' "$tlog" || fail "RetroArch tool lost the header"
grep -q 'core-stdout' "$tlog" || fail "RetroArch tool missed stdout"
grep -q -- '--log-file' "$OUT/ra-args" && fail "RetroArch tool passed --log-file" || true
grep -q -- '^-v$' "$OUT/ra-args" || fail "RetroArch tool did not pass -v"
[ ! -s "$OUT/stdout" ] || fail "RetroArch tool stdout escaped"

# P8 keeps fake08 unless ZLYME_EMU_CORE=native. Both branches log.
cat > "$work/bin/pico8" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$OUT/pico-args"
echo pico-stdout
echo pico-stderr >&2
exit 9
EOF
cat > "$work/bin/ra-run" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$OUT/p8-ra"
echo ra-stdout
exit 3
EOF
chmod 0755 "$work/bin/pico8" "$work/bin/ra-run"
p8=$work/P8.pak
copy_launch "$EMUS/P8.pak/launch.sh" "$p8"
OUT=$work/p8-native
mkdir -p "$OUT" "$work/bios" "$work/saves" "$work/home"
export OUT
set +e
ZLYME_EMU_CORE=native ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$work/p8-native-logs \
	BIOS_PATH=$work/bios SAVES_PATH=$work/saves USERDATA_PATH=$work/home \
	HOME=$work/home \
	sh "$p8/launch.sh" "/carts/Player${q}s Splore.p8" \
	> "$OUT/stdout" 2>"$OUT/stderr"
p8_st=$?
set -e
[ "$p8_st" -eq 9 ] || fail "native pico8 returned $p8_st"
nlog=$work/p8-native-logs/paks/P8.log
grep -q '=== P8' "$nlog" || fail "native pico8 lost the header"
grep -q "Player${q}s Splore.p8" "$nlog" || fail "native pico8 dropped the rom"
grep -q 'pico-stdout' "$nlog" || fail "native pico8 missed stdout"
grep -q 'pico-stderr' "$nlog" || fail "native pico8 missed stderr"
grep -q "Player${q}s Splore.p8" "$OUT/pico-args" || fail "native pico8 argv"
[ ! -e "$OUT/p8-ra" ] || fail "native pico8 called ra-run"
[ ! -s "$OUT/stdout" ] || fail "native pico8 stdout escaped"
OUT=$work/p8-core
mkdir -p "$OUT"
export OUT
set +e
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT=$work/p8-core-logs \
	BIOS_PATH=$work/bios SAVES_PATH=$work/saves USERDATA_PATH=$work/home \
	HOME=$work/home \
	sh "$p8/launch.sh" /carts/game.p8 > "$OUT/stdout" 2>"$OUT/stderr"
p8c_st=$?
set -e
[ "$p8c_st" -eq 3 ] || fail "fake08 branch returned $p8c_st"
grep -q 'fake08_libretro.so' "$OUT/p8-ra" || fail "fake08 branch left the core"
grep -q '=== P8' "$work/p8-core-logs/paks/P8.log" || fail "fake08 branch lost the header"
grep -q 'ra-stdout' "$work/p8-core-logs/paks/P8.log" || fail "fake08 branch missed stdout"
[ ! -e "$OUT/pico-args" ] || fail "fake08 branch called pico8"
unset ZLYME_EMU_CORE
OUT=$work/p8-off
mkdir -p "$OUT"
export OUT
set +e
ZLYME_EMU_CORE=native ZLYME_LOG_ROOT=$work/p8-off-logs \
	BIOS_PATH=$work/bios SAVES_PATH=$work/saves USERDATA_PATH=$work/home \
	HOME=$work/home \
	sh "$p8/launch.sh" /carts/game.p8 > "$OUT/stdout" 2>"$OUT/stderr"
p8off_st=$?
set -e
[ "$p8off_st" -eq 9 ] || fail "pico8 logs-off returned $p8off_st"
grep -q 'pico-stdout' "$OUT/stdout" || fail "pico8 logs-off hid stdout"
[ ! -e "$work/p8-off-logs/paks/P8.log" ] || fail "pico8 logs-off created a pak log"

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
