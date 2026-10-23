#!/bin/sh
# Host checks for the ZLYME1 launch file. No device and no /storage writes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
SESSION=$ROOT/package/system/nextui/nextui-session
AUDIO=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
RA=$ROOT/package/system/nextui/zlyme/ra-run.sh
if [ -n "${NEXTUI_ROOT:-}" ]; then
	NROOT=$NEXTUI_ROOT
else
	NROOT=$(CDPATH= cd -- "$ROOT/../NextUI" && pwd)
fi
LQ=$NROOT/workspace/all/nextui/launch_queue.c
LQT=$NROOT/workspace/all/nextui/launch_queue_test.c
NUI=$NROOT/workspace/all/nextui/nextui.c

fail() {
	echo "pak launch: $*" >&2
	exit 1
}

[ -f "$LAUNCH" ] || fail "missing pak-launch.sh"
[ -f "$LQ" ] || fail "missing $LQ"
[ -f "$LQT" ] || fail "missing $LQT"

work=$(mktemp -d)
ra_cfg=/tmp/zlyme-minui-ra.cfg
if [ -e "$ra_cfg" ]; then
	cp -a "$ra_cfg" "$work/ra-cfg-save"
fi
restore() {
	if [ -e "$work/ra-cfg-save" ]; then
		cp -a "$work/ra-cfg-save" "$ra_cfg"
	else
		rm -f "$ra_cfg"
	fi
	rm -rf "$work"
}
trap restore EXIT
mkdir -p "$work/bin" "$work/out"

# shellcheck disable=SC1090
. "$LAUNCH"

export ZLYME_PAK_BT=0
export ZLYME_PAK_LAUNCH_SH=$LAUNCH
export SESSION_LOG=$work/session.log
export LOGS_ON=0
export ZLYME_SINK_RELOAD=$work/reload
export ZLYME_PROXY_BIN=$work/bin/zlyme-proxy
export ZLYME_DRM_RELEASE=$work/bin/drm
export ZLYME_PAK_HOTKEY=$work/missing-hotkey
export ZLYME_PORTMASTER_CLEANUP=$work/bin/pm
export ZLYME_WINE_PREFIX=$work/bin/wine
export ZLYME_PAK_INPUT=$work/pak-input.sh
export PATH="$work/bin:/usr/bin:/bin"
export http_proxy=from-parent
unset https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY ZLYME_INPUT_FILTER || true

cat > "$work/pak-input.sh" << 'EOF'
export ZLYME_INPUT_FILTER=1
EOF

cat > "$work/bin/drm" << 'EOF'
#!/bin/sh
exit 0
EOF

cat > "$work/bin/pm" << 'EOF'
#!/bin/sh
printf '%s\n' clean >> "$SEQ"
EOF

cat > "$work/bin/wine" << 'EOF'
#!/bin/sh
printf '%s\n' wine >> "$SEQ"
EOF

cat > "$work/bin/zlyme-proxy" << 'EOF'
#!/bin/sh
[ "${1:-}" = get ] || exit 0
cat "$ZLYME_PROXY_GET"
EOF

cat > "$work/bin/hotkey" << 'EOF'
#!/bin/sh
printf '%s\n' "$1" > "$OUT/hotkey-pid"
while :; do
	sleep 1
done
EOF

cat > "$work/recorder" << 'EOF'
#!/bin/sh
printf '%s\n' "$#" > "$OUT/argc"
if [ "$#" -ge 1 ]; then
	printf '%s' "$1" > "$OUT/arg1"
fi
printf '%s\n' "${ZLYME_INPUT_FILTER:-}" > "$OUT/filter"
printf '%s\n' "${http_proxy:-}" > "$OUT/proxy"
printf '%s\n' "$$" > "$OUT/pid"
ps -o sid= -p "$$" | tr -d ' \n' > "$OUT/sid"
printf '%s\n' run >> "$SEQ"
if [ "${ZLYME_WAIT_HOTKEY:-}" = 1 ]; then
	i=0
	while [ ! -s "$OUT/hotkey-pid" ] && [ "$i" -lt 50 ]; do
		sleep 0.05
		i=$((i + 1))
	done
fi
if [ -n "${ZLYME_EXIT:-}" ]; then
	exit "$ZLYME_EXIT"
fi
exit 0
EOF
chmod 0755 "$work/bin/drm" "$work/bin/pm" "$work/bin/wine" \
	"$work/bin/zlyme-proxy" "$work/bin/hotkey" "$work/recorder"

printf '%s\n' 'enabled=0' 'protocol=http' 'host=' 'port=' 'valid=1' > "$work/proxy-get"
export ZLYME_PROXY_GET=$work/proxy-get

cc=${CC:-gcc}
"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/bin/zlyme-pak-spawn" \
	"$ROOT/package/system/nextui/zlyme/zlyme-pak-spawn.c"
"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/lq" "$LQT" "$LQ"
"$work/lq" >/dev/null

target_cc=$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-gcc
if [ -x "$target_cc" ]; then
	"$target_cc" -std=gnu99 -Wall -Wextra -Werror -c -o "$work/lq-target.o" "$LQ"
fi

if grep -n 'escapeSingleQuotes' "$NUI"; then
	fail "NextUI still builds a quoted command"
fi
if grep -n 'queueNext' "$NUI"; then
	fail "NextUI still queues a command string"
fi
if grep -F 'eval "$1"' "$SESSION" "$LAUNCH"; then
	fail "launch still evaluates the payload"
fi
if grep -n 'pak_env' "$SESSION" "$LAUNCH"; then
	fail "launch still interpolates a command prefix"
fi

q=$(printf '\047')
dq=$(printf '\042')
bt=$(printf '\140')
tab=$(printf '\t')
utf=$(printf '\343\203\206\343\202\271\343\203\210')

case_dir() {
	OUT=$work/c$1
	mkdir -p "$OUT"
	SEQ=$OUT/seq
	: > "$SEQ"
	export OUT SEQ
	unset ZLYME_EXIT ZLYME_WAIT_HOTKEY || true
}

install_at() {
	mkdir -p "$(dirname "$1")"
	cp "$work/recorder" "$1"
	chmod 0755 "$1"
}

write_msg() {
	dest=$1
	exe=$2
	rom=${3-}
	if [ -n "$rom" ]; then
		printf 'ZLYME1\n2\n%s\n%s\n' "$exe" "$rom" > "$dest"
	else
		printf 'ZLYME1\n1\n%s\n' "$exe" > "$dest"
	fi
}

expect_reject() {
	name=$1
	file=$work/bad
	shift
	printf '%s' "$1" > "$file"
	if read_launch "$file" 2>"$work/err"; then
		fail "$name was accepted"
	fi
	grep -q 'launch rejected:' "$work/err" || fail "$name had no reason"
	if [ -e "$work/pwned" ]; then
		fail "$name created pwned"
	fi
}

roundtrip() {
	name=$1
	exe=$2
	rom=${3-}
	case_dir "$name"
	install_at "$exe"
	msg=$OUT/msg
	write_msg "$msg" "$exe" "$rom"
	read_launch "$msg" 2>"$work/err" || fail "$name rejected: $(cat "$work/err")"
	[ "$LAUNCH_EXE" = "$exe" ] || fail "$name exe mismatch"
	if [ -n "$rom" ]; then
		[ "$LAUNCH_ROM" = "$rom" ] || fail "$name rom mismatch"
	else
		[ -z "$LAUNCH_ROM" ] || fail "$name invented a rom"
	fi
	run_pak_cmd "$LAUNCH_EXE" "$LAUNCH_ROM"
	# shellcheck disable=SC2154 # set by run_pak_cmd
	[ "$st" -eq 0 ] || fail "$name status $st"
	if [ -n "$rom" ]; then
		printf '%s' "$rom" > "$OUT/expect"
		cmp -s "$OUT/expect" "$OUT/arg1" || fail "$name argv mismatch"
		[ "$(cat "$OUT/argc")" = 1 ] || fail "$name argc"
	else
		[ "$(cat "$OUT/argc")" = 0 ] || fail "$name argc"
		[ ! -e "$OUT/arg1" ] || fail "$name passed an empty rom"
	fi
	[ "$(cat "$OUT/sid")" = "$(cat "$OUT/pid")" ] || fail "$name is not a session leader"
	# shellcheck disable=SC2154 # set by spawn_pak
	[ "$(cat "$OUT/pid")" = "$_pak_pid" ] || fail "$name pid is not the setsid child"
	[ "${ZLYME_INPUT_FILTER-unset}" = unset ] || fail "$name leaked the input filter"
	[ "$http_proxy" = from-parent ] || fail "$name changed the parent proxy"
}

emu=$work/tree/Emus/my355/GB.pak/launch.sh
tool=$work/tree/Tools/my355/Files.pak/launch.sh
settings=$work/tree/Tools/my355/Settings.pak/launch.sh
fn=$work/tree/Tools/my355/Moonlight.pak/launch.sh
resume=$work/tree/Emus/my355/GBA.pak/launch.sh
ports=$work/tree/Emus/my355/PORTS.pak/launch.sh
wine=$work/tree/Emus/my355/WINE.pak/launch.sh
quoted=$work/tree/"it${q}s pak"/GB.pak/launch.sh

roundtrip emu "$emu" "/storage/Roms/GB/game.gb"
[ "$(cat "$work/cemu/filter")" = 1 ] || fail "emulator filter was off"

roundtrip tool "$tool"
launch_skip_bt "$tool" || fail "tool should skip bluetooth"
launch_skip_bt "$emu" && fail "emulator skipped bluetooth" || true
[ "$(cat "$work/ctool/filter")" = 1 ] || fail "tool filter was off"

roundtrip settings "$settings"
[ "$(cat "$work/csettings/filter")" = "" ] || fail "settings got the input filter"
launch_skip_filter "$settings" || fail "settings was not excluded"
launch_skip_bt "$settings" || fail "settings should skip bluetooth"

roundtrip fn "$fn"
launch_skip_bt "$fn" || fail "assigned button should skip bluetooth"
[ "$(cat "$work/cfn/argc")" = 0 ] || fail "assigned button passed a rom"

roundtrip resume "$resume" "/storage/Roms/GBA/save state.gba"
[ "$(cat "$work/cresume/argc")" = 1 ] || fail "resume argc"

spicy="/storage/Roms/GB/it${q}s ${dq}q${dq} ${bt}y${bt} \$x (z);${tab}${utf}"
roundtrip spicy "$quoted" "$spicy"
cmp -s "$work/cspicy/expect" "$work/cspicy/arg1" || fail "metacharacter argv"

roundtrip hyphen "$emu" "-leading.gb"
# emu already exists from the first install. hyphen reuses it.
[ "$(cat "$work/chyphen/arg1")" = "-leading.gb" ] || fail "leading hyphen"

# C writer bytes survive the shell reader and the exec.
case_dir cwriter
install_at "$emu"
crom="/storage/Roms/GB/from writer ${q}${dq}\$x"
if ! "$work/lq" write "$OUT/msg" "$emu" "$crom"; then
	fail "C writer rejected a legal rom"
fi
read_launch "$OUT/msg" || fail "shell rejected the C writer file"
[ "$LAUNCH_ROM" = "$crom" ] || fail "C writer rom mismatch"
run_pak_cmd "$LAUNCH_EXE" "$LAUNCH_ROM"
printf '%s' "$crom" > "$OUT/expect"
cmp -s "$OUT/expect" "$OUT/arg1" || fail "C writer argv mismatch"

expect_reject empty ""
expect_reject magic "NOPE
1
$emu
"
expect_reject argc "ZLYME1
3
$emu
"
expect_reject truncated "ZLYME1
2
$emu
"
expect_reject trailing "ZLYME1
2
$emu
/rom
extra
"
# A valid record plus a fragment with no newline is still trailing.
printf 'ZLYME1\n1\n%s\n' "$emu" > "$work/frag"
printf '%s' 'not-a-field' >> "$work/frag"
if read_launch "$work/frag" 2>"$work/err"; then
	fail "unterminated extra field was accepted"
fi
grep -q 'launch rejected: trailing' "$work/err" || fail "unterminated extra reason"
[ -z "$LAUNCH_EXE" ] || fail "unterminated extra published an executable"
printf 'ZLYME1\n2\n%s\n/r/game.gb\n' "$emu" > "$work/frag2"
printf '%s' ' tail' >> "$work/frag2"
if read_launch "$work/frag2" 2>"$work/err"; then
	fail "unterminated rom trailer was accepted"
fi
grep -q 'launch rejected: trailing' "$work/err" || fail "unterminated rom trailer reason"
[ "$LAUNCH_ROM" != "/r/game.gb" ] || fail "unterminated trailer kept the rom"
expect_reject relative "ZLYME1
1
Emus/GB.pak/launch.sh
"
expect_reject shellbin "ZLYME1
1
/bin/sh
"
expect_reject old "touch $work/pwned
"
expect_reject quoted "'$emu' '; touch $work/pwned'
"
printf 'ZLYME1\n1\n%s\n' "$emu" > "$work/nulmsg"
printf '\000' >> "$work/nulmsg"
if read_launch "$work/nulmsg" 2>"$work/err"; then
	fail "NUL message was accepted"
fi
grep -q 'launch rejected: nul' "$work/err" || fail "NUL reason"
long=$(printf 'ZLYME1\n1\n/%04096d/launch.sh\n' 0)
printf '%s' "$long" > "$work/longmsg"
if read_launch "$work/longmsg" 2>"$work/err"; then
	fail "overlong executable was accepted"
fi

# Spaces and shell globs stay one argument. A control byte is rejected.
pad=" /r/pad .gb "
if ! "$work/lq" write "$work/padmsg" "$emu" "$pad"; then
	fail "C writer rejected surrounding spaces"
fi
read_launch "$work/padmsg" || fail "shell rejected surrounding spaces"
[ "$LAUNCH_ROM" = "$pad" ] || fail "spaces were trimmed"
globrom='/storage/Roms/GB/a*b?[c].gb'
roundtrip glob "$emu" "$globrom"
star=$work/tree/"a*b"/GB.pak/launch.sh
roundtrip star "$star" "/r/star *.gb"
printf 'ZLYME1\n2\n%s\n/r/a\r.gb\n' "$emu" > "$work/cr"
if read_launch "$work/cr" 2>"$work/err"; then
	fail "CR rom was accepted"
fi
grep -q 'launch rejected: control' "$work/err" || fail "CR reason"
printf 'ZLYME1\n2\n%s\n/r/a\001.gb\n' "$emu" > "$work/ctl"
if read_launch "$work/ctl" 2>"$work/err"; then
	fail "control rom was accepted"
fi
grep -q 'launch rejected: control' "$work/err" || fail "control reason"
if "$work/lq" write "$work/cr-c" "$emu" "$(printf '/r/a\rb')"; then
	fail "C writer accepted a carriage return"
fi

# Newline in a field splits the record. Neither piece is executed.
printf 'ZLYME1\n2\n%s\nfoo\nbar\n' "$emu" > "$work/nl"
if read_launch "$work/nl" 2>"$work/err"; then
	fail "newline rom was accepted"
fi
if ! "$work/lq" write "$work/nl-c" "$emu" "$(printf '/r/a\nb')"; then
	:
else
	fail "C writer accepted a newline"
fi
[ ! -e "$work/pwned" ] || fail "rejected launch created pwned"

# A legal record whose ROM would have been shell source.
case_dir evil
install_at "$emu"
evil="; touch $work/pwned"
write_msg "$OUT/msg" "$emu" "$evil"
read_launch "$OUT/msg" || fail "evil rom was rejected"
run_pak_cmd "$LAUNCH_EXE" "$LAUNCH_ROM"
printf '%s' "$evil" > "$OUT/expect"
cmp -s "$OUT/expect" "$OUT/arg1" || fail "evil rom was not preserved"
[ ! -e "$work/pwned" ] || fail "evil rom was executed"
cmdrom="\$(touch $work/pwned)"
write_msg "$OUT/msg2" "$emu" "$cmdrom"
read_launch "$OUT/msg2" || fail "command-substitution rom was rejected"
run_pak_cmd "$LAUNCH_EXE" "$LAUNCH_ROM"
printf '%s' "$cmdrom" > "$OUT/expect"
cmp -s "$OUT/expect" "$OUT/arg1" || fail "command-substitution rom changed"
[ ! -e "$work/pwned" ] || fail "command substitution ran"

# Missing launcher is a failed exec, not another program.
case_dir missing
missing=$work/tree/Emus/my355/NOPE.pak/launch.sh
write_msg "$OUT/msg" "$missing"
read_launch "$OUT/msg" || fail "missing path was an illegal record"
LOGS_ON=1
run_pak_cmd "$LAUNCH_EXE" "$LAUNCH_ROM" 2>"$OUT/err" || fail "run_pak_cmd aborted"
LOGS_ON=0
[ "$st" -eq 127 ] || fail "missing launcher status $st"
grep -q 'missing launcher' "$OUT/err" || fail "missing launcher was silent"
[ ! -e "$work/pwned" ] || fail "missing launcher ran something"

# PortMaster and Wine look at the executable only.
case_dir ports
install_at "$ports"
run_pak_cmd "$ports" "/storage/Roms/not-a-port"
[ "$(cat "$SEQ")" = "clean
run
clean" ] || fail "portmaster cleanup order: $(cat "$SEQ")"

case_dir winecase
install_at "$wine"
run_pak_cmd "$wine" "/storage/Roms/game"
[ "$(cat "$SEQ")" = "wine
run
wine" ] || fail "wine cleanup order: $(cat "$SEQ")"

case_dir romname
install_at "$emu"
run_pak_cmd "$emu" "/storage/Roms/GB/PORTS.pak/WINE.pak/game.gb"
[ "$(cat "$SEQ")" = run ] || fail "rom name selected cleanup: $(cat "$SEQ")"
launch_is_ports "/storage/Roms/GB/PORTS.pak/game.gb" && fail "ports matched a rom" || true
launch_is_wine "/storage/Roms/GB/WINE.pak/game.gb" && fail "wine matched a rom" || true
launch_is_ports "$ports" || fail "ports executable was not classified"
launch_is_wine "$wine" || fail "wine executable was not classified"

# Exit status and the MENU+START codes the session treats as success.
case_dir status
install_at "$emu"
	export ZLYME_EXIT=9
	run_pak_cmd "$emu" "/r/a"
[ "$st" -eq 9 ] || fail "exit status $st"
pak_exit_ok 0 || fail "status 0"
pak_exit_ok 2 || fail "status 2"
pak_exit_ok 3 || fail "status 3"
pak_exit_ok 137 || fail "status 137"
pak_exit_ok 143 || fail "status 143"
pak_exit_ok 9 && fail "status 9 was treated as success" || true
unset ZLYME_EXIT

case_dir hotkey
install_at "$emu"
	ZLYME_PAK_HOTKEY=$work/bin/hotkey
	export ZLYME_WAIT_HOTKEY=1
run_pak_cmd "$emu" "/r/a"
[ "$(cat "$OUT/hotkey-pid")" = "$(cat "$OUT/pid")" ] || fail "hotkey was not given the setsid pid"
[ "$(cat "$OUT/sid")" = "$(cat "$OUT/pid")" ] || fail "hotkey target is not the session leader"
ZLYME_PAK_HOTKEY=$work/missing-hotkey
unset ZLYME_WAIT_HOTKEY

# Sink reload runs the same argv again, then stops.
case_dir reload
install_at "$emu"
cat > "$emu" << 'EOF'
#!/bin/sh
n=0
[ -f "$OUT/n" ] && n=$(cat "$OUT/n")
n=$((n + 1))
printf '%s\n' "$n" > "$OUT/n"
printf '%s' "$1" > "$OUT/arg1"
if [ "$n" -eq 1 ]; then
	: > "$ZLYME_SINK_RELOAD"
fi
exit 0
EOF
chmod 0755 "$emu"
launch_with_reload "$emu" "/r/reload me"
[ "$(cat "$OUT/n")" = 2 ] || fail "reload count $(cat "$OUT/n")"
[ "$(cat "$OUT/arg1")" = "/r/reload me" ] || fail "reload argv"
[ ! -e "$ZLYME_SINK_RELOAD" ] || fail "reload flag remained"

case_dir once
install_at "$emu"
cat > "$emu" << 'EOF'
#!/bin/sh
printf '%s\n' 1 > "$OUT/n"
exit 0
EOF
chmod 0755 "$emu"
launch_with_reload "$emu" ""
[ "$(cat "$OUT/n")" = 1 ] || fail "launched twice without a reload flag"

# Proxy text is data. A hostile host is not exported and is not executed.
case_dir proxy
install_at "$emu"
printf '%s\n' 'enabled=1' 'protocol=http' 'host=10.0.0.8' 'port=8080' 'valid=1' > "$ZLYME_PROXY_GET"
run_pak_cmd "$emu" "/r/a"
[ "$(cat "$OUT/proxy")" = "http://10.0.0.8:8080" ] || fail "proxy url $(cat "$OUT/proxy")"
[ "$http_proxy" = from-parent ] || fail "proxy leaked to the parent"
printf '%s\n' 'enabled=1' 'protocol=http' "host=\$(touch $work/pwned)" 'port=80' 'valid=1' > "$ZLYME_PROXY_GET"
run_pak_cmd "$emu" "/r/a"
[ -z "$(cat "$OUT/proxy")" ] || fail "hostile proxy was exported"
[ ! -e "$work/pwned" ] || fail "hostile proxy was executed"
[ "$http_proxy" = from-parent ] || fail "hostile proxy changed the parent"
printf '%s\n' 'enabled=0' 'protocol=http' 'host=' 'port=' 'valid=1' > "$ZLYME_PROXY_GET"

# Audio export stays a single whitelisted sink assignment.
mkdir -p "$work/acfg"
cat > "$work/zlyme.conf" << EOF
ZLYME_STORAGE=$work/astorage
ZLYME_CFG=$work/acfg
ZLYME_DEFAULTS=/usr/share/zlyme
ZLYME_BOOT=/boot
EOF
printf '%s\n' "ZLYME_SINK=codec; touch $work/pwned-audio" > "$work/acfg/audio.conf"
out=$(ZLYME_CONF=$work/zlyme.conf "$AUDIO" export)
printf '%s\n' "$out" | grep -qx 'ZLYME_SINK=codec; export ZLYME_SINK' || fail "audio export: $out"
[ ! -e "$work/pwned-audio" ] || fail "audio state was executed"
printf '%s\n' "touch $work/pwned-audio" 'ZLYME_SINK=hdmi' > "$work/acfg/audio.conf"
out=$(ZLYME_CONF=$work/zlyme.conf "$AUDIO" export)
printf '%s\n' "$out" | grep -qx 'ZLYME_SINK=hdmi; export ZLYME_SINK' || fail "audio hdmi export: $out"
[ ! -e "$work/pwned-audio" ] || fail "audio command line was executed"
got=$(ZLYME_CONF=$work/zlyme.conf "$AUDIO" export | (
	eval "$(cat)"
	printf '%s' "$ZLYME_SINK"
))
[ "$got" = hdmi ] || fail "eval of audio export produced $got"

# ra-run passes the ROM through without evaluating it.
mkdir -p "$work/xdg/retroarch" "$work/bios" "$work/shared"
: > "$work/bios/.zlyme-ready"
cat > "$work/bin/retroarch" << 'EOF'
#!/bin/sh
printf '%s\n' "$#" > "$OUT/ra-argc"
i=1
for a in "$@"; do
	printf '%s' "$a" > "$OUT/ra-$i"
	i=$((i + 1))
done
printf '%s\n' "${ZLYME_PAK_LOG:-}" > "$OUT/ra-log"
exit 0
EOF
chmod 0755 "$work/bin/retroarch"
ra_rom="/r/it's \"q\" \$x; \$(touch $work/pwned)"
OUT=$work/ra
export OUT
mkdir -p "$OUT"
printf '%s' "$ra_rom" > "$OUT/ra-expect"
mkdir -p "$work/saves"
XDG_CONFIG_HOME=$work/xdg BIOS_PATH=$work/bios SAVES_PATH=$work/saves \
	SHARED_USERDATA_PATH=$work/shared \
	HOME=$work/home EMU_TAG=GB ZLYME_RESOLVED_ROM="$ra_rom" \
	"$RA" -L "/cores/gambatte_libretro.so" "$ra_rom" 2>/dev/null
found=0
i=1
while [ -f "$OUT/ra-$i" ]; do
	if cmp -s "$OUT/ra-$i" "$OUT/ra-expect"; then
		found=1
	fi
	i=$((i + 1))
done
[ "$found" = 1 ] || fail "ra-run changed the rom"
[ ! -e "$work/pwned" ] || fail "ra-run evaluated the rom"
[ -z "$(cat "$OUT/ra-log")" ] || fail "ra-run invented a pak log"

# Trace stays off unless asked. One asked launch records a child that
# left the group, then removes the one-shot flag.
case_dir quiet
unset ZLYME_PAK_TRACE || true
export ZLYME_PAK_TRACE_LOG=$OUT/notrace
export ZLYME_PAK_TRACE_FLAG=$OUT/absent-flag
install_at "$emu"
run_pak_cmd "$emu" "/r/a"
[ ! -e "$OUT/notrace" ] || fail "trace ran without a request"
unset ZLYME_PAK_TRACE_LOG ZLYME_PAK_TRACE_FLAG

case_dir trace
: > "$OUT/flag"
export ZLYME_PAK_TRACE_FLAG=$OUT/flag
export ZLYME_PAK_TRACE_LOG=$OUT/trace
export ZLYME_PAK_TRACE_INTERVAL=0.2
export ZLYME_TRACE_HOLD=2
unset ZLYME_PAK_TRACE || true
ZLYME_PAK_HOTKEY=$work/bin/hotkey
cat > "$ports" << 'EOF'
#!/bin/sh
setsid sleep 30 >/dev/null 2>&1 &
sleep "${ZLYME_TRACE_HOLD:-0.8}"
exit 0
EOF
chmod 0755 "$ports"
run_pak_cmd "$ports" "/r/a"
[ ! -e "$OUT/flag" ] || fail "trace flag survived the launch"
[ "${ZLYME_PAK_TRACE-unset}" = unset ] || fail "trace env leaked"
leader=$(sed -n 's/^leader pid=\([0-9][0-9]*\).*/\1/p' "$OUT/trace" | head -n 1)
[ -n "$leader" ] || fail "trace has no leader"
grep -q "helper pid=" "$OUT/trace" || fail "trace has no helper"
grep -q '^wait status=0$' "$OUT/trace" || fail "trace wait: $(cat "$OUT/trace")"
grep -q '^cleanup ports$' "$OUT/trace" || fail "trace skipped cleanup"
out=$(awk -v leader="$leader" '
	$1 == "outside" {
		pid = $2
		sub("pid=", "", pid)
		ppid = $3
		sub("ppid=", "", ppid)
		pgid = $4
		sub("pgid=", "", pgid)
		if (ppid == leader && pgid != leader) {
			print pid
			found = 1
		}
	}
	END { exit found ? 0 : 1 }
' "$OUT/trace") || fail "no child outside the group: $(cat "$OUT/trace")"
kill "$out" 2>/dev/null || true
unset ZLYME_PAK_TRACE_FLAG ZLYME_PAK_TRACE_LOG ZLYME_PAK_TRACE_INTERVAL ZLYME_TRACE_HOLD
ZLYME_PAK_HOTKEY=$work/missing-hotkey

echo "pak launch ok"
