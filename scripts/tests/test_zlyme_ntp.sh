#!/bin/sh
# Host tests for clock bootstrap and ntpd. No network and no real RTC.
set -eu
# A caller may export these. They would stall or skip the checks below.
unset ZLYME_NTP_HOLD ZLYME_NTP_FORCE
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
NTP="$ROOT/board/my355/fsoverlay/etc/init.d/S49ntp"
work=$(mktemp -d)

stop_left() {
	for f in "$work/run/zlyme-ntp.pid" "$work/run/zlyme-ntpd.pid"; do
		[ -f "$f" ] || continue
		pid=$(tr -d ' \t\r\n' < "$f" || true)
		case "$pid" in
			''|*[!0-9]*) ;;
			*)
				pkill -P "$pid" 2>/dev/null || true
				kill "$pid" 2>/dev/null || true
				;;
		esac
	done
}

trap 'stop_left; rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/run"
printf 'KEEP\n' > "$work/localtime"

cat > "$work/bin/date" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_NTP_DATE_LOG:?}"
exit 0
EOF
cat > "$work/bin/hwclock" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_NTP_HWCLOCK_LOG:?}"
exit 0
EOF
cat > "$work/bin/ntpd" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_NTP_NTPD_LOG:?}"
echo $$ >> "${ZLYME_NTP_NTPD_PIDS:?}"
if [ "${ZLYME_NTP_NTPD_EXIT:-}" = 1 ]; then
	exit 0
fi
exec sleep "${ZLYME_NTP_NTPD_SLEEP:-30}"
EOF
cat > "$work/bin/zlyme-ctl" <<'EOF'
#!/bin/sh
if [ "$1" = want ] && [ "$2" = wifi ]; then
	[ "${ZLYME_WIFI:-on}" = on ]
	exit
fi
exit 0
EOF
cat > "$work/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' called >> "${ZLYME_NTP_CURL_LOG:?}"
exit 1
EOF
chmod 0755 "$work/bin/date" "$work/bin/hwclock" "$work/bin/ntpd" \
	"$work/bin/zlyme-ctl" "$work/bin/curl"

fail() {
	printf 'FAIL %s\n' "$1" >&2
	exit 1
}

reset_logs() {
	: > "$work/date.log"
	: > "$work/hwclock.log"
	: > "$work/ntpd.log"
	: > "$work/ntpd.pids"
	: > "$work/curl.log"
	stop_left
	rm -rf "$work/run/zlyme-ntp.pid" "$work/run/zlyme-ntpd.pid" "$work/run/zlyme-ntp.lock"
}

run_ntp() {
	env \
		PATH="$work/bin:$PATH" \
		ZLYME_NTP_PIDDIR="$work/run" \
		ZLYME_NTP_DATE_LOG="$work/date.log" \
		ZLYME_NTP_HWCLOCK_LOG="$work/hwclock.log" \
		ZLYME_NTP_NTPD_LOG="$work/ntpd.log" \
		ZLYME_NTP_NTPD_PIDS="$work/ntpd.pids" \
		ZLYME_NTP_CURL_LOG="$work/curl.log" \
		ZLYME_NTP_NO_SLEEP=1 \
		ZLYME_NTP_FOREGROUND=1 \
		"$NTP" "$@"
}

hw_count() {
	if [ ! -s "$work/hwclock.log" ]; then
		printf '0'
		return
	fi
	wc -l < "$work/hwclock.log" | tr -d ' '
}

run_ntp_bg() {
	env \
		PATH="$work/bin:$PATH" \
		ZLYME_NTP_PIDDIR="$work/run" \
		ZLYME_NTP_DATE_LOG="$work/date.log" \
		ZLYME_NTP_HWCLOCK_LOG="$work/hwclock.log" \
		ZLYME_NTP_NTPD_LOG="$work/ntpd.log" \
		ZLYME_NTP_NTPD_PIDS="$work/ntpd.pids" \
		ZLYME_NTP_CURL_LOG="$work/curl.log" \
		ZLYME_NTP_NO_SLEEP=1 \
		"$NTP" "$@"
}

alive_ntpd() {
	n=0
	if [ -s "$work/ntpd.pids" ]; then
		while read -r p; do
			kill -0 "$p" 2>/dev/null && n=$((n + 1))
		done < "$work/ntpd.pids"
	fi
	printf '%s' "$n"
}

wait_ntp_idle() {
	i=0
	while [ "$i" -lt 160 ]; do
		if [ ! -d "$work/run/zlyme-ntp.lock" ]; then
			w=""
			if [ -f "$work/run/zlyme-ntp.pid" ]; then
				w=$(tr -d ' \t\r\n' < "$work/run/zlyme-ntp.pid")
			fi
			if [ -z "$w" ] || ! kill -0 "$w" 2>/dev/null; then
				return 0
			fi
		fi
		sleep 0.05
		i=$((i + 1))
	done
	return 1
}

# Invalid RTC: bootstrap, then ntpd. The timezone file stays put.
reset_logs
ZLYME_NTP_YEAR=2017 \
	ZLYME_NTP_ROUTE=1 \
	ZLYME_NTP_CURL_DATE='Tue, 15 Sep 2026 01:32:00 GMT' \
	ZLYME_WIFI=on \
	run_ntp start
grep -q -- '-u -s 2026-09-15 01:32:00' "$work/date.log" || fail "bootstrap did not set UTC"
grep -q -- '-u -w' "$work/hwclock.log" || fail "bootstrap did not write the RTC"
grep -q 'time.cloudflare.com' "$work/ntpd.log" || fail "ntpd peer missing"
grep -q 'pool.ntp.org' "$work/ntpd.log" || fail "second ntp peer missing"
grep -q -- '-S ' "$work/ntpd.log" || fail "ntpd has no step callback"
[ "$(hw_count)" = 1 ] || fail "bootstrap wrote the RTC more than once"
cmp "$work/localtime" - <<'EOF' || fail "timezone file changed"
KEEP
EOF
[ ! -s "$work/curl.log" ] || fail "bootstrap called curl when a date was supplied"

# A valid clock skips HTTP and still starts ntpd.
reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp start
[ ! -s "$work/date.log" ] || fail "valid clock ran date"
[ "$(hw_count)" = 0 ] || fail "valid clock wrote the RTC at start"
[ -s "$work/ntpd.log" ] || fail "valid clock did not start ntpd"

# Failed connectivity: no route, do not set the clock or start ntpd.
reset_logs
ZLYME_NTP_YEAR=2017 ZLYME_NTP_ROUTE=0 ZLYME_NTP_TRIES=2 ZLYME_WIFI=on run_ntp start
[ ! -s "$work/date.log" ] || fail "no-route set the clock"
[ ! -s "$work/ntpd.log" ] || fail "no-route started ntpd"
[ ! -s "$work/curl.log" ] || fail "no-route called curl"

# HTTP failed, route exists: still start ntpd. Do not invent a time.
reset_logs
ZLYME_NTP_YEAR=2017 \
	ZLYME_NTP_ROUTE=1 \
	ZLYME_NTP_CURL_DATE= \
	ZLYME_NTP_BOOT_TRIES=1 \
	ZLYME_WIFI=on \
	run_ntp start
[ ! -s "$work/date.log" ] || fail "failed HTTP set the clock"
[ "$(hw_count)" = 0 ] || fail "failed HTTP wrote the RTC"
[ -s "$work/ntpd.log" ] || fail "failed HTTP did not start ntpd"

# Wi-Fi disabled and no route: do not poll and do not sync.
reset_logs
ZLYME_NTP_YEAR=2017 ZLYME_NTP_ROUTE=0 ZLYME_WIFI=off ZLYME_NTP_TRIES=40 run_ntp start
[ ! -s "$work/curl.log" ] || fail "wifi-off called curl"
[ ! -s "$work/ntpd.log" ] || fail "wifi-off started ntpd"

# Wi-Fi disabled but a route exists: still sync, without the HTTP bootstrap.
reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=off run_ntp start
[ -s "$work/ntpd.log" ] || fail "route without wifi did not start ntpd"
[ ! -s "$work/date.log" ] || fail "route without wifi bootstrapped a valid clock"

# ntpd missing: bootstrap still corrects an invalid clock.
reset_logs
mv "$work/bin/ntpd" "$work/bin/ntpd.off"
ZLYME_NTP_YEAR=2017 \
	ZLYME_NTP_ROUTE=1 \
	ZLYME_NTP_CURL_DATE='Tue, 15 Sep 2026 01:32:00 GMT' \
	ZLYME_WIFI=on \
	run_ntp start
grep -q -- '-u -s 2026-09-15 01:32:00' "$work/date.log" || fail "missing ntpd skipped bootstrap"
[ "$(hw_count)" = 1 ] || fail "missing ntpd skipped the RTC write"
mv "$work/bin/ntpd.off" "$work/bin/ntpd"

# BusyBox callback: the action is the argument and offset is the
# environment variable. A number passed as the argument is not a step.
reset_logs
offset=45.2 run_ntp step
offset=-45.2 run_ntp step
offset=1.5 run_ntp step
offset=29.9 run_ntp step
offset=30 run_ntp step
offset=-30 run_ntp step
unset offset || true
run_ntp step
offset=hello run_ntp step
offset=45.2x run_ntp step
offset=80 run_ntp stratum
offset=80 run_ntp periodic
offset=80 run_ntp unsync
offset=80 run_ntp something
run_ntp 45.2
[ "$(hw_count)" = 4 ] || fail "RTC writes were $(hw_count), want 4"
grep -q -- '-u -w' "$work/hwclock.log" || fail "step write was not UTC"
while read -r hwline; do
	case "$hwline" in
		*-u*-w*|*-w*-u*) ;;
		*) fail "RTC write was not UTC: $hwline" ;;
	esac
done < "$work/hwclock.log"

# One ntpd. A second start does not add another. Reopen and a later
# kick after it died do.
reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp start
first=$(cat "$work/run/zlyme-ntpd.pid")
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp start
second=$(cat "$work/run/zlyme-ntpd.pid")
[ "$first" = "$second" ] || fail "second start replaced ntpd"
[ "$(wc -l < "$work/ntpd.log" | tr -d ' ')" = 1 ] || fail "second start launched ntpd"
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp kick
[ "$(cat "$work/run/zlyme-ntpd.pid")" = "$first" ] || fail "kick restarted a live ntpd"
kill "$first" 2>/dev/null || true
# The pidfile still names the dead process. kick must replace it.
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp kick
third=$(cat "$work/run/zlyme-ntpd.pid")
[ "$third" != "$first" ] || fail "kick after exit did not start ntpd"
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp reopen
fourth=$(cat "$work/run/zlyme-ntpd.pid")
[ "$fourth" != "$third" ] || fail "reopen did not restart ntpd"
kill "$fourth" 2>/dev/null || true

# A lock whose owner was killed is stolen. Otherwise every later
# start would wait out the lock timeout.
reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on ZLYME_NTP_HOLD=5 \
	run_ntp_bg start
i=0
while [ ! -s "$work/run/zlyme-ntp.lock/pid" ] && [ "$i" -lt 50 ]; do
	sleep 0.05
	i=$((i + 1))
done
[ -s "$work/run/zlyme-ntp.lock/pid" ] || fail "lock owner was not published"
holder=$(tr -d ' \t\r\n' < "$work/run/zlyme-ntp.lock/pid")
pkill -P "$holder" 2>/dev/null || true
kill -9 "$holder" 2>/dev/null || true
i=0
while kill -0 "$holder" 2>/dev/null && [ "$i" -lt 50 ]; do
	sleep 0.05
	i=$((i + 1))
done
kill -0 "$holder" 2>/dev/null && fail "lock owner was not reaped"
begin=$(date +%s)
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp start
end=$(date +%s)
[ $((end - begin)) -lt 3 ] || fail "stale lock was not recovered"
[ -s "$work/run/zlyme-ntpd.pid" ] || fail "stale lock recovery did not start ntpd"
recovered=$(tr -d ' \t\r\n' < "$work/run/zlyme-ntpd.pid")
kill -0 "$recovered" 2>/dev/null || fail "stale lock recovery client is dead"
stop_left

# A stale pidfile names a dead process. start replaces it.
reset_logs
sleep 0.1 &
dead=$!
wait "$dead" || true
echo "$dead" > "$work/run/zlyme-ntpd.pid"
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp start
stale_new=$(cat "$work/run/zlyme-ntpd.pid")
[ "$stale_new" != "$dead" ] || fail "stale pidfile was kept"
kill -0 "$stale_new" 2>/dev/null || fail "stale pidfile was not replaced with a live client"
kill "$stale_new" 2>/dev/null || true

# No route: do not leave the client polling.
reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on run_ntp start
live=$(cat "$work/run/zlyme-ntpd.pid")
kill -0 "$live" 2>/dev/null || fail "client was not running before the route dropped"
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=0 ZLYME_WIFI=off ZLYME_NTP_TRIES=40 run_ntp kick
kill -0 "$live" 2>/dev/null && fail "disconnected kick left ntpd running"
[ "$(wc -l < "$work/ntpd.log" | tr -d ' ')" = 1 ] || fail "disconnected kick started another client"

# Overlapping start, kick, and reopen must leave one live client.
reset_logs
i=0
while [ "$i" -lt 6 ]; do
	ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on \
		ZLYME_NTP_HOLD=0.3 ZLYME_NTP_FORCE=1 \
		run_ntp_bg start &
	i=$((i + 1))
done
wait
wait_ntp_idle || fail "concurrent starts did not finish"
[ "$(wc -l < "$work/ntpd.log" | tr -d ' ')" = 1 ] || fail "concurrent starts launched more than one client"
[ "$(alive_ntpd)" = 1 ] || fail "concurrent starts left $(alive_ntpd) clients"

reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on \
	ZLYME_NTP_HOLD=0.4 ZLYME_NTP_FORCE=1 \
	run_ntp_bg start &
i=0
while [ "$i" -lt 4 ]; do
	ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on \
		ZLYME_NTP_HOLD=0.2 ZLYME_NTP_FORCE=1 \
		run_ntp_bg kick &
	i=$((i + 1))
done
wait
wait_ntp_idle || fail "kick during startup did not finish"
[ "$(wc -l < "$work/ntpd.log" | tr -d ' ')" = 1 ] || fail "kick during startup launched more than one client"
[ "$(alive_ntpd)" = 1 ] || fail "kick during startup left $(alive_ntpd) clients"
kick_pid=$(cat "$work/run/zlyme-ntpd.pid")
kill -0 "$kick_pid" 2>/dev/null || fail "kick during startup left a dead pidfile"

reset_logs
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on \
	ZLYME_NTP_HOLD=0.4 ZLYME_NTP_FORCE=1 \
	run_ntp_bg start &
ZLYME_NTP_YEAR=2026 ZLYME_NTP_ROUTE=1 ZLYME_WIFI=on \
	ZLYME_NTP_HOLD=0.2 ZLYME_NTP_FORCE=1 \
	run_ntp_bg reopen &
wait
wait_ntp_idle || fail "reopen during startup did not finish"
[ "$(alive_ntpd)" = 1 ] || fail "reopen during startup left $(alive_ntpd) clients"
re_pid=$(cat "$work/run/zlyme-ntpd.pid")
kill -0 "$re_pid" 2>/dev/null || fail "reopen killed its replacement"
stop_left

# Start returns without waiting for a route. That is the first-frame path.
reset_logs
begin=$(date +%s)
env \
	PATH="$work/bin:$PATH" \
	ZLYME_NTP_PIDDIR="$work/run" \
	ZLYME_NTP_DATE_LOG="$work/date.log" \
	ZLYME_NTP_HWCLOCK_LOG="$work/hwclock.log" \
	ZLYME_NTP_NTPD_LOG="$work/ntpd.log" \
	ZLYME_NTP_NTPD_PIDS="$work/ntpd.pids" \
	ZLYME_NTP_CURL_LOG="$work/curl.log" \
	ZLYME_NTP_ROUTE=0 \
	ZLYME_NTP_TRIES=40 \
	ZLYME_NTP_YEAR=2017 \
	ZLYME_WIFI=on \
	"$NTP" start
end=$(date +%s)
elapsed=$((end - begin))
[ "$elapsed" -lt 2 ] || fail "start blocked for ${elapsed}s"
[ -s "$work/run/zlyme-ntp.pid" ] || fail "background worker was not recorded"
stop_left

grep -q 'start_bg /etc/init.d/S49ntp' "$ROOT/board/my355/fsoverlay/etc/init.d/rc.late" \
	|| fail "ntp is not a background late service"
grep -q '/etc/init.d/S49ntp kick' "$ROOT/board/my355/fsoverlay/etc/init.d/S30wifi" \
	|| fail "wifi does not kick ntp"
grep -q '/etc/init.d/S49ntp reopen' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-radios" \
	|| fail "resume does not reopen ntp"
grep -q 'CONFIG_NTPD=y' "$ROOT/board/my355/busybox.fragment" || fail "ntpd fragment"
grep -q 'CONFIG_FEATURE_NTPD_SERVER is not set' "$ROOT/board/my355/busybox.fragment" \
	|| fail "ntpd server mode"
grep -q 'busybox.fragment' "$ROOT/configs/zlyme_my355_defconfig" || fail "product defconfig"
grep -q 'busybox.fragment' "$ROOT/configs/zlyme_my355_minimal_defconfig" || fail "minimal defconfig"
grep -q '# CONFIG_NTPD is not set' "$ROOT/package/boot/zlyme-initramfs/busybox.config" \
	|| fail "initramfs gained ntpd"
cmp "$work/localtime" - <<'EOF' || fail "timezone file changed at the end"
KEEP
EOF
if grep -n '/etc/localtime' "$NTP"; then
	fail "S49ntp writes the timezone"
fi

printf 'ok\n'
