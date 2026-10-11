#!/bin/sh
# Host tests for the LED watcher battery policy. Sysfs is a temp tree.
# The real zlyme-halt is never executed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-led"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/leds/green:power" "$work/leds/red:status"
printf '1\n' > "$work/leds/green:power/max_brightness"
printf '1\n' > "$work/leds/red:status/max_brightness"
printf 'none\n' > "$work/leds/green:power/trigger"
printf 'none\n' > "$work/leds/red:status/trigger"
printf '0\n' > "$work/leds/green:power/brightness"
printf '0\n' > "$work/leds/red:status/brightness"

cat > "$work/bin/zlyme-ctl" <<'EOF'
#!/bin/sh
if [ "$1" = get ] && [ "$2" = led ]; then
	cat "${ZLYME_CTL_LED:?}"
	exit 0
fi
exit 0
EOF
cat > "$work/bin/zlyme-halt" <<'EOF'
#!/bin/sh
echo "real halt invoked: $*" >> "${ZLYME_LED_HALT_FORBIDDEN:?}"
exit 99
EOF
chmod 0755 "$work/bin/zlyme-ctl" "$work/bin/zlyme-halt"

fail() {
	printf 'FAIL %s\n' "$1" >&2
	exit 1
}

supply() {
	local cap=$1 status=$2 online=$3
	rm -rf "$work/ps"
	mkdir -p "$work/ps/battery" "$work/ps/usb"
	printf 'Battery\n' > "$work/ps/battery/type"
	printf '%s\n' "$status" > "$work/ps/battery/status"
	if [ "$cap" = missing ]; then
		:
	else
		printf '%s\n' "$cap" > "$work/ps/battery/capacity"
	fi
	printf 'USB\n' > "$work/ps/usb/type"
	printf '%s\n' "$online" > "$work/ps/usb/online"
}

run_watch() {
	local loops=$1
	: > "$work/halt.log"
	: > "$work/trace.log"
	: > "$work/forbidden.log"
	env \
		PATH="$work/bin:$PATH" \
		ZLYME_LED_PATH="$work/leds" \
		ZLYME_LED_PS="$work/ps" \
		ZLYME_LED_HALT="$work/halt.log" \
		ZLYME_LED_HALT_FORBIDDEN="$work/forbidden.log" \
		ZLYME_LED_TRACE="$work/trace.log" \
		ZLYME_LED_NO_SLEEP=1 \
		ZLYME_LED_LOOPS="$loops" \
		ZLYME_CTL_LED="$work/ledcolor" \
		"$BIN" watch
}

assert_halt() {
	local expect=$1
	local n
	n=$(wc -l < "$work/halt.log" | tr -d ' ')
	[ "$n" = "$expect" ] || fail "halt lines $n want $expect"
	if [ "$expect" != 0 ]; then
		[ "$(cat "$work/halt.log")" = poweroff ] || fail "halt verb"
	fi
	[ ! -s "$work/forbidden.log" ] || fail "real halt ran"
}

trace_count() {
	local color=$1
	if [ ! -s "$work/trace.log" ]; then
		printf '0'
		return
	fi
	grep -c "^${color}$" "$work/trace.log" || true
}

printf 'battery\n' > "$work/ledcolor"

supply 11 Discharging 0
run_watch 2
assert_halt 0
[ "$(trace_count red)" = 0 ] || fail "11% must not warn"
[ "$(trace_count green)" != 0 ] || fail "11% stays on the user colour"

supply 10 Discharging 0
run_watch 1
assert_halt 0
[ "$(trace_count red)" = 1 ] || fail "10% first sample is solid red"

supply 10 Discharging 0
run_watch 6
assert_halt 0
# one solid red, then three flash pulses
[ "$(trace_count red)" = 4 ] || fail "10% flash count $(trace_count red)"

supply 1 Discharging 0
run_watch 2
assert_halt 0
[ "$(trace_count red)" = 1 ] || fail "1% warns once in two samples"

supply 0 Discharging 0
run_watch 1
assert_halt 0
[ "$(trace_count red)" = 1 ] || fail "single 0% warns and does not shut down"

supply 0 Discharging 0
run_watch 2
assert_halt 1

supply 0 Discharging 0
run_watch 5
assert_halt 1

supply 0 Discharging 1
run_watch 4
assert_halt 0
[ "$(trace_count red)" != 0 ] || fail "online charger keeps the charging colour"

# Status says Charging while online is 0. Shutdown follows online, not the string.
supply 0 Charging 0
run_watch 2
assert_halt 1

# One watcher: apply reads the first value, then each sample reads once.
# 0% followed by 40% must clear the streak.
rm -rf "$work/ps"
mkdir -p "$work/ps/battery" "$work/ps/usb"
printf 'Battery\n' > "$work/ps/battery/type"
printf 'Discharging\n' > "$work/ps/battery/status"
mkfifo "$work/ps/battery/capacity"
printf 'USB\n' > "$work/ps/usb/type"
printf '0\n' > "$work/ps/usb/online"
(
	printf '50\n' > "$work/ps/battery/capacity"
	printf '0\n' > "$work/ps/battery/capacity"
	printf '40\n' > "$work/ps/battery/capacity"
	while true; do
		printf '40\n' > "$work/ps/battery/capacity" || exit 0
	done
) &
feed=$!
run_watch 3
kill "$feed" 2>/dev/null || true
wait "$feed" 2>/dev/null || true
assert_halt 0

supply nope Discharging 0
run_watch 3
assert_halt 0

supply '' Discharging 0
run_watch 3
assert_halt 0

supply missing Discharging 0
run_watch 3
assert_halt 0
[ "$(trace_count red)" = 0 ] || fail "missing capacity is not a low battery"

printf 'off\n' > "$work/ledcolor"
supply 0 Discharging 0
run_watch 2
assert_halt 1
[ "$(trace_count red)" = 0 ] || fail "LED Off must not paint red"
[ "$(trace_count green)" = 0 ] || fail "LED Off must not paint green"

# A killed watcher does not shut down on its way out.
supply 40 Discharging 0
: > "$work/halt.log"
: > "$work/forbidden.log"
env \
	PATH="$work/bin:$PATH" \
	ZLYME_LED_PATH="$work/leds" \
	ZLYME_LED_PS="$work/ps" \
	ZLYME_LED_HALT="$work/halt.log" \
	ZLYME_LED_HALT_FORBIDDEN="$work/forbidden.log" \
	ZLYME_LED_NO_SLEEP=1 \
	ZLYME_CTL_LED="$work/ledcolor" \
	"$BIN" watch >/dev/null 2>&1 &
pid=$!
sleep 0.2
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
assert_halt 0

grep -q 'ZLYME_LED_INTERVAL:-10' "$BIN" || fail "poll default is not 10s"
grep -q '/usr/sbin/zlyme-halt poweroff' "$BIN" || fail "shutdown verb missing"

printf 'ok\n'
