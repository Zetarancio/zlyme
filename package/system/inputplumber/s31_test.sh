#!/bin/sh
# Host stand-in for BusyBox start-stop-daemon. The device script calls
# the real applet; this only checks the script's start/stop contract.
set -eu
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/bin"
cat > "$root/bin/start-stop-daemon" <<'EOF'
#!/bin/sh
pidfile= execbin=
mode=
while [ $# -gt 0 ]; do
	case "$1" in
		-S) mode=start; shift ;;
		-K) mode=stop; shift ;;
		-q|-b|-m) shift ;;
		-p) pidfile=$2; shift 2 ;;
		--exec) execbin=$2; shift 2 ;;
		*) shift ;;
	esac
done
if [ "$mode" = start ]; then
	if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
		exit 1
	fi
	"$execbin" &
	echo $! > "$pidfile"
	exit 0
fi
if [ "$mode" = stop ]; then
	if [ -f "$pidfile" ]; then
		kill "$(cat "$pidfile")" 2>/dev/null || true
	fi
	exit 0
fi
exit 1
EOF
chmod +x "$root/bin/start-stop-daemon"
cat > "$root/fake-ip" <<'EOF'
#!/bin/sh
env > "$INPUTPLUMBER_ENV_DUMP"
exec sleep 30
EOF
chmod +x "$root/fake-ip"
export PATH="$root/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export INPUTPLUMBER_BIN="$root/fake-ip"
export INPUTPLUMBER_PIDFILE="$root/ip.pid"
export INPUTPLUMBER_LOG="$root/ip.log"
export INPUTPLUMBER_ENV_DUMP="$root/env"
script=$(CDPATH= cd -- "$(dirname "$0")" && pwd)/S31inputplumber

"$script" start
pid=$(cat "$INPUTPLUMBER_PIDFILE")
kill -0 "$pid"
grep -q '^INSECURE_DISABLE_POLKIT=1$' "$INPUTPLUMBER_ENV_DUMP"
grep -q '^HIDE_DEVICES_FROM_ROOT=0$' "$INPUTPLUMBER_ENV_DUMP"
if grep -q '^ENABLE_METRICS=' "$INPUTPLUMBER_ENV_DUMP"; then
	echo "metrics must stay unset" >&2
	exit 1
fi
"$script" start
test "$(cat "$INPUTPLUMBER_PIDFILE")" = "$pid"
"$script" stop
if kill -0 "$pid" 2>/dev/null; then
	echo "stop left the daemon running" >&2
	exit 1
fi
echo 999999 > "$INPUTPLUMBER_PIDFILE"
"$script" start
newpid=$(cat "$INPUTPLUMBER_PIDFILE")
test "$newpid" != 999999
kill -0 "$newpid"
"$script" stop
echo S31_OK
