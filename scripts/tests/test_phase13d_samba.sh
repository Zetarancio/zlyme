#!/bin/sh
# Phase 13D1. Isolated files and stubbed Samba tools. No Windows client.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
auth=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-samba-auth
init=$ROOT/board/my355/fsoverlay/etc/init.d/S70samba
shipped=$ROOT/board/my355/fsoverlay/etc/samba/smb.conf
reset=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-reset

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

grep -q '/var/run/samba' "$init" || fail "start does not create the pipe directory parent"
grep -q 'pidof smbd' "$init" || fail "start does not check that smbd stayed up"
grep -q 'map to guest = Never' "$shipped" || fail "shipped map to guest"
grep -q 'guest ok = no' "$shipped" || fail "shipped guest ok"
grep -q 'disable netbios = yes' "$shipped" || fail "shipped netbios"
grep -q 'server min protocol = SMB2' "$shipped" || fail "shipped smb2"
grep -q 'private dir = /var/lib/samba/private' "$shipped" || fail "shipped private dir"
grep -q 'valid users = zlyme' "$shipped" || fail "shipped valid users"
grep -q 'path = /storage' "$shipped" || fail "shipped share path"
if grep -q 'guest ok = yes\|map to guest = Bad User\|wsdd\|nmbd' "$shipped"; then
	fail "shipped conf still opens guest or discovery"
fi
awk '
	/^start\(\)/ { f=1 }
	/^stop\(\)/ { f=0 }
	f && /nmbd/ { bad=1 }
	END { exit bad ? 1 : 0 }
' "$init" || fail "start still mentions nmbd"
if grep -q 'samba.account' "$reset"; then
	fail "settings reset deletes the samba account"
fi
if grep -n 'chmod .*samba.account\|samba.account .*chmod' "$auth"; then
	fail "account file mode is treated as the access boundary"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/cfg/zlyme" "$work/tmp" "$work/etc" "$work/runtime"
printf '%s\n' 'root:x:0:0:root:/root:/bin/sh' 'daemon:x:1:1:daemon:/usr/sbin:/bin/false' > "$work/etc/passwd"
printf '%s\n' 'root:x:0:' 'daemon:x:1:' > "$work/etc/group"

cat > "$work/bin/smbpasswd" <<'EOF'
#!/bin/sh
set -eu
log=${ZLYME_SAMBA_LOG:?}
if [ "${ZLYME_SAMBA_PASSWD_FAIL:-0}" = 1 ]; then
	printf 'smbpasswd %s\n' "$*" >> "$log.argv"
	exit 1
fi
printf 'smbpasswd %s\n' "$*" >> "$log.argv"
env >> "$log.env"
conf=
add=0
while [ $# -gt 0 ]; do
	case $1 in
		-c) conf=$2; shift 2 ;;
		-a) add=1; shift ;;
		-s|--) shift ;;
		*) shift ;;
	esac
done
IFS= read -r a
IFS= read -r b || true
[ "$a" = "$b" ] || exit 1
[ -n "$a" ] || exit 1
printf '%s\n' "$a" >> "$log.stdin"
priv=$(awk '
	tolower($0) ~ /^[ \t]*private dir[ \t]*=/ {
		sub(/^[^=]*=[ \t]*/, "")
		sub(/[ \t]*$/, "")
		print
		exit
	}
' "$conf")
[ -n "$priv" ] || exit 1
case "$priv" in
	/storage|/storage/*|/mnt/SDCARD|/mnt/SDCARD/*) exit 1 ;;
esac
mkdir -p "$priv"
if [ "$add" -eq 0 ] && [ ! -f "$priv/nt.hash" ]; then
	exit 1
fi
printf '%s' "$a" | sha256sum | awk '{print substr($1,1,32)}' > "$priv/nt.hash"
EOF

cat > "$work/bin/pdbedit" <<'EOF'
#!/bin/sh
set -eu
log=${ZLYME_SAMBA_LOG:?}
printf 'pdbedit %s\n' "$*" >> "$log.argv"
conf=
mode=
spec=
while [ $# -gt 0 ]; do
	case $1 in
		-s) conf=$2; shift 2 ;;
		-L) mode=list; shift ;;
		-i) mode=import; spec=$2; shift 2 ;;
		-e) mode=export; spec=$2; shift 2 ;;
		*) shift ;;
	esac
done
priv=$(awk '
	tolower($0) ~ /^[ \t]*private dir[ \t]*=/ {
		sub(/^[^=]*=[ \t]*/, "")
		sub(/[ \t]*$/, "")
		print
		exit
	}
' "$conf")
[ -n "$priv" ] || exit 1
case "$mode" in
	list)
		if [ -f "$priv/nt.hash" ]; then
			printf '%s\n' 'zlyme:980:Samba'
		fi
		;;
	export)
		file=${spec#smbpasswd:}
		hash=$(cat "$priv/nt.hash")
		# Samba 4.24.6 writes uid 0. Import must not treat that as success.
		printf 'zlyme:0:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:%s:[U          ]:LCT-00000001\n' "$hash" > "$file"
		;;
	import)
		file=${spec#smbpasswd:}
		uid=$(awk -F: '$1=="zlyme" { print $2; exit }' "$file")
		[ "$uid" = 980 ] || exit 1
		hash=$(awk -F: '$1=="zlyme" { print $4; exit }' "$file")
		printf '%s\n' "$hash" | grep -Eq '^[0-9A-Fa-f]{32}$' || exit 1
		mkdir -p "$priv"
		printf '%s\n' "$hash" > "$priv/nt.hash"
		;;
	*) exit 1 ;;
esac
EOF

cat > "$work/bin/zlyme-ctl" <<'EOF'
#!/bin/sh
if [ "${1:-}" != want ]; then
	exit 1
fi
case "${2:-}" in
	samba) [ "${ZLYME_SAMBA_WANT:-0}" = 1 ] ;;
	wifi) [ "${ZLYME_WIFI_WANT:-1}" = 1 ] ;;
	*) exit 1 ;;
esac
EOF

cat > "$work/bin/start-stop-daemon" <<'EOF'
#!/bin/sh
log=${ZLYME_SAMBA_LOG:?}
printf '%s\n' "$*" >> "$log.ssd"
start=0
while [ $# -gt 0 ]; do
	case $1 in
		-S) start=1 ;;
		-K) rm -f "$log.running" ;;
	esac
	shift
done
if [ "$start" -eq 1 ] && [ "${ZLYME_SAMBA_SMBD_EXITS:-0}" != 1 ]; then
	: > "$log.running"
fi
exit 0
EOF

cat > "$work/bin/pidof" <<'EOF'
#!/bin/sh
[ "$1" = smbd ] && [ -f "${ZLYME_SAMBA_LOG:?}.running" ]
EOF

cat > "$work/bin/mkdir" <<'EOF'
#!/bin/sh
log=${ZLYME_SAMBA_LOG:?}
real=0
for arg in "$@"; do
	case $arg in
		-*) ;;
		/var/run/samba|/var/cache/samba|/var/lock/samba|/var/log/samba)
			printf '%s\n' "$arg" >> "$log.mkdir"
			;;
		*) real=1 ;;
	esac
done
if [ "$real" -eq 1 ]; then
	/usr/bin/mkdir "$@"
fi
exit 0
EOF

cat > "$work/bin/smbd" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$work/bin/smbpasswd" "$work/bin/pdbedit" "$work/bin/zlyme-ctl" \
	"$work/bin/start-stop-daemon" "$work/bin/pidof" "$work/bin/mkdir" \
	"$work/bin/smbd" "$auth"
ln -s "$auth" "$work/bin/zlyme-samba-auth"

write_conf() {
	dest=$1
	priv=$2
	guest=$3
	cat > "$dest" <<EOF
[global]
	security = user
	map to guest = Never
	disable netbios = yes
	server min protocol = SMB2
	passdb backend = tdbsam
	private dir = $priv
	logging = 0
[storage]
	path = /storage
	guest ok = $guest
	valid users = zlyme
	force user = root
EOF
}

export ZLYME_SAMBA_LOG="$work/log"
export ZLYME_SAMBA_NO_MOUNT=1
export ZLYME_SAMBA_RUNTIME="$work/runtime"
export ZLYME_CFG="$work/cfg"
export ZLYME_SAMBA_CONF="$work/smb.conf"
export ZLYME_SAMBA_PASSWD_SRC="$work/etc/passwd"
export ZLYME_SAMBA_GROUP_SRC="$work/etc/group"
export ZLYME_SMB_PASSWD="$work/bin/smbpasswd"
export ZLYME_PDBEDIT="$work/bin/pdbedit"
export TMPDIR="$work/tmp"
export PATH="$work/bin:$PATH"
: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.stdin"
: > "$ZLYME_SAMBA_LOG.env"
: > "$ZLYME_SAMBA_LOG.ssd"

hash_of() {
	awk -F: '$1=="zlyme" { print $4; exit }' "$1"
}

write_conf "$ZLYME_SAMBA_CONF" "$ZLYME_SAMBA_RUNTIME/private" no

# Disabled: no account and no smbd.
ZLYME_SAMBA_WANT=0
export ZLYME_SAMBA_WANT
out=$("$init" start)
printf '%s\n' "$out" | grep -q 'Samba: disabled' || fail "disabled start was not quiet"
[ ! -s "$ZLYME_SAMBA_LOG.argv" ] || fail "disabled start prepared an account"
[ ! -s "$ZLYME_SAMBA_LOG.ssd" ] || fail "disabled start launched smbd"
[ ! -f "$ZLYME_CFG/zlyme/samba.account" ] || fail "disabled start wrote an account"

# Package absent: stay quiet, still do not prepare.
mv "$work/bin/smbd" "$work/bin/smbd.off"
ZLYME_SAMBA_WANT=1
"$init" start
[ ! -s "$ZLYME_SAMBA_LOG.argv" ] || fail "missing smbd still prepared an account"
mv "$work/bin/smbd.off" "$work/bin/smbd"

# Guest and an exFAT private dir fail before any password tool runs.
write_conf "$work/guest.conf" "$ZLYME_SAMBA_RUNTIME/private" yes
ZLYME_SAMBA_CONF=$work/guest.conf
if ZLYME_SAMBA_CONF=$work/guest.conf "$auth" prepare >"$work/guest.out" 2>"$work/guest.err"; then
	fail "guest conf was accepted"
fi
grep -q 'Samba authentication failed' "$work/guest.err" || fail "guest failure was not reported"
[ ! -s "$ZLYME_SAMBA_LOG.argv" ] || fail "guest conf called a password tool"
write_conf "$work/fat.conf" /storage/zlyme-phase13d-not-a-db no
if ZLYME_SAMBA_CONF=$work/fat.conf "$auth" prepare >"$work/fat.out" 2>"$work/fat.err"; then
	rm -rf /storage/zlyme-phase13d-not-a-db
	fail "exFAT private dir was accepted"
fi
if [ -d /storage/zlyme-phase13d-not-a-db ]; then
	rm -rf /storage/zlyme-phase13d-not-a-db
	fail "live database was created on the card"
fi
[ ! -s "$ZLYME_SAMBA_LOG.argv" ] || fail "exFAT private dir called a password tool"
export ZLYME_SAMBA_CONF="$work/smb.conf"

# Initial account, then a change that survives restart and a wiped runtime.
"$auth" prepare >"$work/prep.out" 2>"$work/prep.err"
[ ! -s "$work/prep.out" ] || fail "prepare printed a password"
if grep -q 'zlyme' "$work/prep.err"; then
	fail "prepare logged the initial password"
fi
grep -qx 'zlyme' "$ZLYME_SAMBA_LOG.stdin" || fail "initial password was not the account name"
grep -q 'smbpasswd -c .* -a -s -- zlyme' "$ZLYME_SAMBA_LOG.argv" || fail "account was not created"
store=$ZLYME_CFG/zlyme/samba.account
[ -f "$store" ] || fail "account export missing"
h0=$(hash_of "$store")
[ "${#h0}" -eq 32 ] || fail "export is not an NT hash"
awk -F: '$1=="zlyme" && $2=="980" { ok=1 } END { exit ok ? 0 : 1 }' "$store" \
	|| fail "export kept uid 0"
[ "$h0" != zlyme ] || fail "export stored the password"
grep -q '^zlyme:x:980:980:Samba:/var/empty:/bin/false$' "$ZLYME_SAMBA_RUNTIME/passwd" || fail "unix account"
grep -q '^root:x:0:0:root:/root:/bin/sh$' "$ZLYME_SAMBA_RUNTIME/passwd" || fail "root account changed"
grep -q '^zlyme:x:980:$' "$ZLYME_SAMBA_RUNTIME/group" || fail "group"
[ ! -e "$ZLYME_SAMBA_RUNTIME/shadow" ] || fail "shadow was written"
[ -f "$ZLYME_SAMBA_RUNTIME/private/nt.hash" ] || fail "live hash is not on the runtime filesystem"
[ "$ZLYME_SAMBA_RUNTIME/private/nt.hash" != "$store" ] || fail "live hash and export are the same file"

secret=s3cret-token
printf '%s\n' "$secret" | "$auth" set >"$work/set.out" 2>"$work/set.err"
grep -q 'Samba password updated' "$work/set.out" || fail "set did not confirm"
if grep -F "$secret" "$work/set.out" "$work/set.err" "$ZLYME_SAMBA_LOG.argv" "$ZLYME_SAMBA_LOG.env" "$store" "$ZLYME_SAMBA_RUNTIME/passwd"; then
	fail "password leaked"
fi
h1=$(hash_of "$store")
[ "$h1" != "$h0" ] || fail "password did not change"
grep -q "$h1" "$ZLYME_SAMBA_RUNTIME/private/nt.hash" || fail "live hash was not updated"

# Ordinary start keeps the changed hash and does not create the account again.
: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.ssd"
"$auth" prepare
if grep -q 'smbpasswd' "$ZLYME_SAMBA_LOG.argv"; then
	fail "ordinary start rewrote the password"
fi
[ "$(hash_of "$store")" = "$h1" ] || fail "ordinary start replaced the export"

ZLYME_SAMBA_WANT=1
"$init" restart >"$work/restart.out" 2>"$work/restart.err"
grep -q -- '-K -q --exec /usr/sbin/smbd' "$ZLYME_SAMBA_LOG.ssd" || fail "stop did not stop smbd"
grep -q -- '-S -q --exec /usr/sbin/smbd' "$ZLYME_SAMBA_LOG.ssd" || fail "start did not start smbd"
if grep -q -- '-S .*nmbd' "$ZLYME_SAMBA_LOG.ssd"; then
	fail "nmbd was started"
fi
[ "$(hash_of "$store")" = "$h1" ] || fail "restart replaced the password"
if grep -F "$secret" "$work/restart.out" "$work/restart.err"; then
	fail "restart logged the password"
fi

# Reboot and OTA keep the card export and rebuild tmpfs from it.
rm -rf "$ZLYME_SAMBA_RUNTIME"
mkdir -p "$ZLYME_SAMBA_RUNTIME"
: > "$ZLYME_SAMBA_LOG.argv"
"$auth" prepare
grep -q 'pdbedit .* -i smbpasswd:' "$ZLYME_SAMBA_LOG.argv" || fail "reboot did not import"
if grep -q 'smbpasswd .* -a ' "$ZLYME_SAMBA_LOG.argv"; then
	fail "reboot recreated the default account"
fi
[ "$(hash_of "$store")" = "$h1" ] || fail "reboot replaced the export"
grep -q "$h1" "$ZLYME_SAMBA_RUNTIME/private/nt.hash" || fail "imported hash mismatch"

# Corrupt export: do not fall back to guest or to the public password.
printf '%s\n' 'not-a-database' > "$store"
rm -rf "$ZLYME_SAMBA_RUNTIME/private"
: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.ssd"
if "$auth" prepare >"$work/bad.out" 2>"$work/bad.err"; then
	fail "corrupt account was accepted"
fi
grep -q 'Samba authentication failed' "$work/bad.err" || fail "corrupt failure was not reported"
if grep -q 'smbpasswd' "$ZLYME_SAMBA_LOG.argv"; then
	fail "corrupt account was recreated"
fi
[ "$(cat "$store")" = 'not-a-database' ] || fail "corrupt account was overwritten"
if ZLYME_SAMBA_WANT=1 "$init" start >"$work/bad-start.out" 2>"$work/bad-start.err"; then
	fail "smbd started with a corrupt account"
fi
grep -q 'Samba: authentication failed' "$work/bad-start.out" || fail "start hid the auth failure"
if grep -q -- '-S ' "$ZLYME_SAMBA_LOG.ssd"; then
	fail "smbd was launched after auth failure"
fi
if grep -F "$secret" "$work/bad.out" "$work/bad.err" "$work/bad-start.out" "$work/bad-start.err"; then
	fail "failure path logged the password"
fi

# No live account: the typed password replaces the damaged export.
# It is not the public password.
: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.stdin"
recover=recovered-secret
printf '%s\n' "$recover" | "$auth" set >"$work/recover.out" 2>"$work/recover.err"
grep -q 'Samba password updated' "$work/recover.out" || fail "recovery set failed"
hr=$(hash_of "$store")
[ "${#hr}" -eq 32 ] || fail "recovery export is not a hash"
[ "$hr" != "$h0" ] || fail "recovery used the public password"
[ "$(cat "$store")" != 'not-a-database' ] || fail "recovery left the damaged export"
if grep -F "$recover" "$work/recover.out" "$work/recover.err" "$ZLYME_SAMBA_LOG.argv" "$store"; then
	fail "recovery leaked the password"
fi
grep -q 'smbpasswd .* -a ' "$ZLYME_SAMBA_LOG.argv" || fail "recovery without a live account did not create one"
tail -n 1 "$ZLYME_SAMBA_LOG.stdin" | grep -qx "$recover" || fail "recovery did not use the typed password"

# A failed password tool leaves the previous export in place.
: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.stdin"
kept=$(hash_of "$store")
if printf '%s\n' 'should-not-stick' | ZLYME_SAMBA_PASSWD_FAIL=1 "$auth" set >"$work/failset.out" 2>"$work/failset.err"; then
	fail "a failed password tool was treated as success"
fi
[ "$(hash_of "$store")" = "$kept" ] || fail "a failed password tool replaced the export"
if grep -F 'should-not-stick' "$work/failset.out" "$work/failset.err" "$ZLYME_SAMBA_LOG.argv" "$store"; then
	fail "a failed password tool leaked the typed password"
fi

# Samba 4.24.6 leaves uid 0 on the card. The next start repairs that
# field and imports the same hash.
rm -rf "$ZLYME_SAMBA_RUNTIME"
mkdir -p "$ZLYME_SAMBA_RUNTIME"
printf 'zlyme:0:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:%s:[U          ]:LCT-00000001\n' "$h1" > "$store"
: > "$ZLYME_SAMBA_LOG.argv"
"$auth" prepare
if grep -q 'smbpasswd .* -a ' "$ZLYME_SAMBA_LOG.argv"; then
	fail "uid 0 export was replaced with the public password"
fi
[ "$(hash_of "$store")" = "$h1" ] || fail "uid repair changed the hash"
awk -F: '$1=="zlyme" && $2=="980" { ok=1 } END { exit ok ? 0 : 1 }' "$store" \
	|| fail "uid 0 export was not repaired"
grep -q "$h1" "$ZLYME_SAMBA_RUNTIME/private/nt.hash" || fail "uid 0 export was not imported"

# A changed password left on the card is what the next image imports.
rm -rf "$ZLYME_SAMBA_RUNTIME"
mkdir -p "$ZLYME_SAMBA_RUNTIME" "$ZLYME_CFG/zlyme"
printf 'zlyme:980:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:%s:[U          ]:LCT-00000001\n' "$h1" > "$store"
: > "$ZLYME_SAMBA_LOG.argv"
"$auth" prepare
if grep -q 'smbpasswd .* -a ' "$ZLYME_SAMBA_LOG.argv"; then
	fail "OTA recreated the default account"
fi
[ "$(hash_of "$store")" = "$h1" ] || fail "OTA replaced the export"
grep -q "$h1" "$ZLYME_SAMBA_RUNTIME/private/nt.hash" || fail "OTA import mismatch"

# Corrupt export while the tmpfs account is already loaded.
printf '%s\n' 'not-a-database' > "$store"
live=$(cat "$ZLYME_SAMBA_RUNTIME/private/nt.hash")
: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.ssd"
if "$auth" prepare >"$work/live-bad.out" 2>"$work/live-bad.err"; then
	fail "corrupt export was accepted because a live account exists"
fi
[ "$(cat "$store")" = 'not-a-database' ] || fail "live account rewrote the damaged export"
[ "$(cat "$ZLYME_SAMBA_RUNTIME/private/nt.hash")" = "$live" ] || fail "failed prepare changed the live hash"
if grep -q 'smbpasswd' "$ZLYME_SAMBA_LOG.argv"; then
	fail "live corrupt path rewrote the password"
fi
if ZLYME_SAMBA_WANT=1 "$init" restart >"$work/live-bad-start.out" 2>"$work/live-bad-start.err"; then
	fail "restart started Samba with a damaged export"
fi
if grep -q -- '-S ' "$ZLYME_SAMBA_LOG.ssd"; then
	fail "smbd started from a live account with a damaged export"
fi

: > "$ZLYME_SAMBA_LOG.argv"
: > "$ZLYME_SAMBA_LOG.stdin"
: > "$ZLYME_SAMBA_LOG.ssd"
recover2=another-secret
printf '%s\n' "$recover2" | "$auth" set >"$work/live-recover.out" 2>"$work/live-recover.err"
hr2=$(hash_of "$store")
[ "$hr2" != "$h0" ] || fail "live recovery used the public password"
[ "$hr2" != "$h1" ] || fail "live recovery kept the old hash"
grep -q "$hr2" "$ZLYME_SAMBA_RUNTIME/private/nt.hash" || fail "live recovery did not update the account"
if grep -q 'smbpasswd .* -a ' "$ZLYME_SAMBA_LOG.argv"; then
	fail "live recovery created a new default account"
fi
if grep -F "$recover2" "$work/live-recover.out" "$work/live-recover.err" "$ZLYME_SAMBA_LOG.argv" "$store"; then
	fail "live recovery leaked the password"
fi
"$auth" prepare >"$work/live-ok.out" 2>"$work/live-ok.err"
[ "$(hash_of "$store")" = "$hr2" ] || fail "prepare after recovery replaced the password"
ZLYME_SAMBA_WANT=1 "$init" restart >"$work/live-restart.out" 2>"$work/live-restart.err"
grep -q -- '-S -q --exec /usr/sbin/smbd' "$ZLYME_SAMBA_LOG.ssd" || fail "restart after recovery did not start smbd"
[ "$(hash_of "$store")" = "$hr2" ] || fail "restart after recovery replaced the password"

# The launcher exits 0 and the process is already gone. That is not a share.
: > "$ZLYME_SAMBA_LOG.ssd"
rm -f "$ZLYME_SAMBA_LOG.running"
if ZLYME_SAMBA_SMBD_EXITS=1 "$init" start >"$work/gone.out" 2>"$work/gone.err"; then
	fail "a dead smbd was reported as started"
fi
grep -q 'FAIL' "$work/gone.out" || fail "a dead smbd was not reported"
if [ -f "$ZLYME_SAMBA_LOG.running" ]; then
	fail "a dead smbd stayed marked running"
fi

echo "phase 13D samba auth ok"
