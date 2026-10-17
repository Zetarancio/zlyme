#!/bin/sh
# SSH, Samba, and Syncthing follow the Wi-Fi flag. No radio and no daemons.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
HELPER=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-net-services
WIFI=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-wifi
LATE=$ROOT/board/my355/fsoverlay/etc/init.d/rc.late
S50=$ROOT/board/my355/fsoverlay/etc/init.d/S50sshd
S70=$ROOT/board/my355/fsoverlay/etc/init.d/S70samba
S75=$ROOT/board/my355/fsoverlay/etc/init.d/S75syncthing

fail() {
	echo "net services: $*" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/state" "$work/init"
log=$work/log
: > "$log"

cat > "$work/bin/zlyme-ctl" <<'EOF'
#!/bin/sh
state=${ZLYME_CTL_STATE:?}
log=${ZLYME_CTL_LOG:?}
case "${1:-}" in
	want)
		[ "$(cat "$state/${2:-}" 2>/dev/null || true)" = on ]
		;;
	set)
		printf '%s\n' "${3:-}" > "$state/${2:-}"
		printf 'set %s %s\n' "${2:-}" "${3:-}" >> "$log"
		;;
	*)
		exit 1
		;;
esac
EOF
chmod 755 "$work/bin/zlyme-ctl"

mkinit() {
	name=$1
	cat > "$work/init/$name" <<EOF
#!/bin/sh
printf '%s %s\\n' "$name" "\${1:-}" >> "$log"
if [ "\${1:-}" = start ] && [ "$name" = samba ] && [ "\${ZLYME_NET_SAMBA_FAIL:-0}" = 1 ]; then
	exit 1
fi
exit 0
EOF
	chmod 755 "$work/init/$name"
}
mkinit ssh
mkinit samba
mkinit syncthing

flag() {
	printf '%s\n' "$2" > "$work/state/$1"
}

run_apply() {
	ZLYME_CTL_STATE=$work/state \
	ZLYME_CTL_LOG=$log \
	ZLYME_NET_LOCK=$work/lock \
	ZLYME_NET_SSH_INIT=$work/init/ssh \
	ZLYME_NET_SAMBA_INIT=$work/init/samba \
	ZLYME_NET_SYNCTHING_INIT=$work/init/syncthing \
	ZLYME_NET_SAMBA_FAIL=${1:-0} \
	PATH="$work/bin:$PATH" \
	"$HELPER" apply
}

run_named() {
	ZLYME_CTL_STATE=$work/state \
	ZLYME_CTL_LOG=$log \
	ZLYME_NET_LOCK=$work/lock \
	ZLYME_NET_SSH_INIT=$work/init/ssh \
	ZLYME_NET_SAMBA_INIT=$work/init/samba \
	ZLYME_NET_SYNCTHING_INIT=$work/init/syncthing \
	PATH="$work/bin:$PATH" \
	"$HELPER" apply "$1"
}

flag wifi off
flag ssh on
flag samba on
flag syncthing on
: > "$log"
run_apply
grep -qx 'ssh stop' "$log" || fail "wifi off did not stop ssh"
grep -qx 'samba stop' "$log" || fail "wifi off did not stop samba"
grep -qx 'syncthing stop' "$log" || fail "wifi off did not stop syncthing"
grep -q ' start$' "$log" && fail "wifi off started a service"
[ "$(cat "$work/state/ssh")" = on ] || fail "wifi off cleared ssh"
[ "$(cat "$work/state/samba")" = on ] || fail "wifi off cleared samba"
[ "$(cat "$work/state/syncthing")" = on ] || fail "wifi off cleared syncthing"

flag wifi on
flag samba off
: > "$log"
run_apply
grep -qx 'ssh start' "$log" || fail "enabled ssh did not start"
grep -qx 'samba stop' "$log" || fail "disabled samba was not stopped"
grep -qx 'syncthing start' "$log" || fail "enabled syncthing did not start"
[ "$(cat "$work/state/samba")" = off ] || fail "disabled samba flag changed"

: > "$log"
run_apply
grep -qx 'ssh start' "$log" || fail "repeat apply dropped ssh"

flag wifi off
: > "$log"
run_apply
grep -q ' start$' "$log" && fail "turning wifi off left a start"
grep -qx 'ssh stop' "$log" || fail "turning wifi off did not stop ssh"

flag wifi on
flag samba on
: > "$log"
if run_apply 1; then
	fail "samba failure was ignored"
fi
grep -qx 'samba start' "$log" || fail "failing samba was not attempted"
grep -qx 'syncthing start' "$log" || fail "a samba failure stopped syncthing"
grep -qx 'ssh start' "$log" || fail "a samba failure stopped ssh"

flag wifi off
flag ssh on
flag samba on
flag syncthing on
: > "$log"
run_named ssh
grep -qx 'ssh stop' "$log" || fail "ssh toggle while wifi was off did not stop ssh"
grep -q 'samba ' "$log" && fail "ssh toggle changed samba"
grep -q 'syncthing ' "$log" && fail "ssh toggle changed syncthing"
[ "$(cat "$work/state/ssh")" = on ] || fail "ssh toggle while wifi was off cleared ssh"

flag wifi on
: > "$log"
run_named ssh
run_named ssh
[ "$(grep -c '^ssh start$' "$log")" = 2 ] || fail "repeat ssh start was not idempotent"
if "$HELPER" apply nope >/dev/null 2>&1; then
	fail "unknown service was accepted"
fi

# Direct init start must not launch the daemon while Wi-Fi is off.
cat > "$work/bin/smbd" <<'EOF'
#!/bin/sh
printf 'smbd\n' >> "${ZLYME_CTL_LOG:?}"
exit 0
EOF
cat > "$work/bin/syncthing" <<'EOF'
#!/bin/sh
printf 'syncthing-bin\n' >> "${ZLYME_CTL_LOG:?}"
exit 0
EOF
chmod 755 "$work/bin/smbd" "$work/bin/syncthing"
flag wifi off
flag ssh on
flag samba on
flag syncthing on
: > "$log"
ZLYME_CTL_STATE=$work/state ZLYME_CTL_LOG=$log PATH="$work/bin:$PATH" \
	"$S50" start
grep -q 'sshd' "$log" && fail "ssh started while wifi was off"
: > "$log"
ZLYME_CTL_STATE=$work/state ZLYME_CTL_LOG=$log PATH="$work/bin:$PATH" \
	"$S70" start
grep -q 'smbd' "$log" && fail "samba started while wifi was off"
: > "$log"
ZLYME_CTL_STATE=$work/state ZLYME_CTL_LOG=$log PATH="$work/bin:$PATH" \
	ZLYME_SYNCTHING=$work/bin/syncthing \
	"$S75" start
grep -q 'syncthing-bin' "$log" && fail "syncthing started while wifi was off"

if [ -x /etc/init.d/S30wifi ]; then
	fail "host S30wifi is executable; refusing to run zlyme-wifi"
fi
unset SYSTEM_PATH || true
mkdir -p "$work/async"
cat > "$work/net" <<'EOF'
#!/bin/sh
# The reconciler calls this after the flag is saved. A slow or failing
# pass must not be the Wi-Fi command's wait.
if [ "${ZLYME_NET_APPLY_FAIL:-0}" = 1 ]; then
	printf 'apply-fail\n' >> "${ZLYME_CTL_LOG:?}"
	exit 1
fi
sleep "${ZLYME_NET_APPLY_DELAY:-0}"
printf 'apply\n' >> "${ZLYME_CTL_LOG:?}"
exit 0
EOF
chmod 755 "$work/net"

wait_idle() {
	i=0
	while [ -d "$work/async/worker" ] || [ -f "$work/async/dirty" ]; do
		i=$((i + 1))
		[ "$i" -lt 80 ] || fail "service reconciler did not finish"
		sleep 0.05
	done
}

wifi_cmd() {
	IFACE=lo \
	ZLYME_CTL_STATE=$work/state \
	ZLYME_CTL_LOG=$log \
	ZLYME_NET_SERVICES=$work/net \
	ZLYME_NET_ASYNC_DIR=$work/async \
	ZLYME_NET_ASYNC_LOG=$work/async.log \
	ZLYME_NET_APPLY_DELAY=${1:-0} \
	ZLYME_NET_APPLY_FAIL=${2:-0} \
	PATH="$work/bin:$PATH" \
		"$WIFI" "$3"
}

: > "$log"
wifi_cmd 0 0 enable
wait_idle
[ "$(sed -n '1p' "$log")" = "set wifi on" ] || fail "enable did not set wifi first"
grep -qx 'apply' "$log" || fail "enable did not apply services after the flag"
[ "$(cat "$work/state/wifi")" = on ] || fail "enable left wifi off"
: > "$log"
wifi_cmd 0 0 disable
wait_idle
[ "$(sed -n '1p' "$log")" = "set wifi off" ] || fail "disable did not clear wifi first"
grep -qx 'apply' "$log" || fail "disable did not stop services after the flag"
[ "$(cat "$work/state/wifi")" = off ] || fail "disable left wifi on"

# The command returns while a slow pass is still running.
: > "$log"
start=$(date +%s%N)
wifi_cmd 1 0 enable
end=$(date +%s%N)
elapsed=$(( (end - start) / 1000000 ))
[ "$elapsed" -lt 400 ] || fail "enable waited ${elapsed}ms for services"
grep -qx 'apply' "$log" && fail "enable did not return before the slow pass"
wait_idle
grep -qx 'apply' "$log" || fail "slow pass never ran"
[ "$(cat "$work/state/wifi")" = on ] || fail "slow enable left wifi off"

# A failing pass does not undo the saved flag.
: > "$log"
wifi_cmd 0 1 disable
status=$?
wait_idle
[ "$status" -eq 0 ] || fail "a service failure failed the Wi-Fi command"
grep -qx 'apply-fail' "$log" || fail "failing pass was not attempted"
[ "$(cat "$work/state/wifi")" = off ] || fail "failed pass changed the Wi-Fi flag"

# Rapid on/off/on. The worker rereads the flag, so the last pass wins.
: > "$log"
wifi_cmd 0.2 0 enable
wifi_cmd 0.2 0 disable
wifi_cmd 0.2 0 enable
[ "$(cat "$work/state/wifi")" = on ] || fail "rapid toggles left wifi off"
wait_idle
[ -d "$work/async/worker" ] && fail "reconciler was still running"
# No new worker appears after the last pass.
sleep 0.2
[ -d "$work/async/worker" ] && fail "reconciler restarted with no new request"
applies=$(grep -c '^apply$' "$log" || true)
[ "$applies" -ge 1 ] || fail "rapid toggles never reconciled"
# The flag was on before the worker could be observed finished.
# Run one more settled pass and require that it saw Wi-Fi on.
: > "$log"
wifi_cmd 0 0 enable
wait_idle
grep -qx 'apply' "$log" || fail "settled enable did not reconcile"
[ "$(cat "$work/state/wifi")" = on ] || fail "settled enable left wifi off"

# The real helper rereads the flag under its lock. A worker started by
# enable must not leave the services up after a following disable.
cat > "$work/init/ssh" <<EOF
#!/bin/sh
sleep 0.25
printf 'ssh %s\n' "\${1:-}" >> "$log"
exit 0
EOF
cat > "$work/init/samba" <<EOF
#!/bin/sh
sleep 0.25
printf 'samba %s\n' "\${1:-}" >> "$log"
exit 0
EOF
cat > "$work/init/syncthing" <<EOF
#!/bin/sh
sleep 0.25
printf 'syncthing %s\n' "\${1:-}" >> "$log"
exit 0
EOF
chmod 755 "$work/init/ssh" "$work/init/samba" "$work/init/syncthing"
flag wifi off
flag ssh on
flag samba on
flag syncthing on
: > "$log"
rm -rf "$work/async"
mkdir -p "$work/async"
IFACE=lo \
ZLYME_CTL_STATE=$work/state \
ZLYME_CTL_LOG=$log \
ZLYME_NET_SERVICES=$HELPER \
ZLYME_NET_ASYNC_DIR=$work/async \
ZLYME_NET_LOCK=$work/real.lock \
ZLYME_NET_SSH_INIT=$work/init/ssh \
ZLYME_NET_SAMBA_INIT=$work/init/samba \
ZLYME_NET_SYNCTHING_INIT=$work/init/syncthing \
PATH="$work/bin:$PATH" \
	"$WIFI" enable
IFACE=lo \
ZLYME_CTL_STATE=$work/state \
ZLYME_CTL_LOG=$log \
ZLYME_NET_SERVICES=$HELPER \
ZLYME_NET_ASYNC_DIR=$work/async \
ZLYME_NET_LOCK=$work/real.lock \
ZLYME_NET_SSH_INIT=$work/init/ssh \
ZLYME_NET_SAMBA_INIT=$work/init/samba \
ZLYME_NET_SYNCTHING_INIT=$work/init/syncthing \
PATH="$work/bin:$PATH" \
	"$WIFI" disable
[ "$(cat "$work/state/wifi")" = off ] || fail "rapid disable did not save wifi off"
i=0
while [ -d "$work/async/worker" ] || [ -f "$work/async/dirty" ]; do
	i=$((i + 1))
	[ "$i" -lt 200 ] || fail "real reconciler did not finish"
	sleep 0.05
done
for name in ssh samba syncthing; do
	last=$(grep "^$name " "$log" | tail -n 1)
	[ "$last" = "$name stop" ] || fail "final $name action was '$last'"
done

grep -q 'start_bg /usr/sbin/zlyme-net-services' "$LATE" || fail "rc.late does not apply network services"
grep -q 'start_bg /etc/init.d/S50sshd' "$LATE" && fail "rc.late still starts ssh directly"
grep -q 'start_bg /etc/init.d/S70samba' "$LATE" && fail "rc.late still starts samba directly"
grep -q 'start_bg /etc/init.d/S75syncthing' "$LATE" && fail "rc.late still starts syncthing directly"
grep -q 'start_bg /etc/init.d/S30wifi' "$LATE" || fail "rc.late dropped wifi"
grep -q 'start_bg /etc/init.d/S46btsink' "$LATE" || fail "rc.late dropped bluetooth"

echo "net services ok"
