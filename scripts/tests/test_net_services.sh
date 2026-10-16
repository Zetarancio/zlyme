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
run_apply 1
grep -qx 'samba start' "$log" || fail "failing samba was not attempted"
grep -qx 'syncthing start' "$log" || fail "a samba failure stopped syncthing"

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
cat > "$work/net" <<'EOF'
#!/bin/sh
printf 'apply\n' >> "${ZLYME_CTL_LOG:?}"
exit 0
EOF
chmod 755 "$work/net"
: > "$log"
IFACE=lo \
ZLYME_CTL_STATE=$work/state \
ZLYME_CTL_LOG=$log \
ZLYME_NET_SERVICES=$work/net \
PATH="$work/bin:$PATH" \
	"$WIFI" enable
[ "$(sed -n '1p' "$log")" = "set wifi on" ] || fail "enable did not set wifi first"
[ "$(sed -n '2p' "$log")" = "apply" ] || fail "enable did not apply services after the flag"
[ "$(cat "$work/state/wifi")" = on ] || fail "enable left wifi off"
: > "$log"
IFACE=lo \
ZLYME_CTL_STATE=$work/state \
ZLYME_CTL_LOG=$log \
ZLYME_NET_SERVICES=$work/net \
PATH="$work/bin:$PATH" \
	"$WIFI" disable
[ "$(sed -n '1p' "$log")" = "set wifi off" ] || fail "disable did not clear wifi first"
[ "$(sed -n '2p' "$log")" = "apply" ] || fail "disable did not stop services after the flag"
[ "$(cat "$work/state/wifi")" = off ] || fail "disable left wifi on"
: > "$log"
IFACE=lo ZLYME_CTL_STATE=$work/state ZLYME_CTL_LOG=$log ZLYME_NET_SERVICES=$work/net \
	PATH="$work/bin:$PATH" "$WIFI" enable
IFACE=lo ZLYME_CTL_STATE=$work/state ZLYME_CTL_LOG=$log ZLYME_NET_SERVICES=$work/net \
	PATH="$work/bin:$PATH" "$WIFI" disable
IFACE=lo ZLYME_CTL_STATE=$work/state ZLYME_CTL_LOG=$log ZLYME_NET_SERVICES=$work/net \
	PATH="$work/bin:$PATH" "$WIFI" enable
[ "$(cat "$work/state/wifi")" = on ] || fail "repeated toggles left wifi off"
grep -c '^apply$' "$log" | grep -qx 3 || fail "repeated toggles skipped a service pass"

grep -q 'start_bg /usr/sbin/zlyme-net-services' "$LATE" || fail "rc.late does not apply network services"
grep -q 'start_bg /etc/init.d/S50sshd' "$LATE" && fail "rc.late still starts ssh directly"
grep -q 'start_bg /etc/init.d/S70samba' "$LATE" && fail "rc.late still starts samba directly"
grep -q 'start_bg /etc/init.d/S75syncthing' "$LATE" && fail "rc.late still starts syncthing directly"
grep -q 'start_bg /etc/init.d/S30wifi' "$LATE" || fail "rc.late dropped wifi"
grep -q 'start_bg /etc/init.d/S46btsink' "$LATE" || fail "rc.late dropped bluetooth"

echo "net services ok"
