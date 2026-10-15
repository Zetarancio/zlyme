#!/bin/sh
# Phase 13E2. Syncthing 2.0.13 generate, then the init script.
# The listener check is on 127.0.0.1 with the host-built binary.
# It is not a Flip test.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
INIT=$ROOT/board/my355/fsoverlay/etc/init.d/S75syncthing
SRC=$ROOT/output/build/syncthing-2.0.13
REAL=${ZLYME_SYNCTHING_REAL:-/tmp/zlyme-syncthing-host/syncthing}
CTL=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ctl

fail() {
	printf 'syncthing: %s\n' "$*" >&2
	exit 1
}

[ -x "$REAL" ] || fail "host syncthing is missing at $REAL"
[ -d "$SRC/vendor/golang.org/x/crypto/bcrypt" ] || fail "vendored bcrypt is missing"
grep -q 'samba|syncthing) echo off' "$CTL" || fail "syncthing is not off by default"
grep -q -- '--gui-password=-' "$INIT" || fail "password is not read from stdin"
if grep -q -- '--gui-password=zlyme' "$INIT"; then
	fail "initial password is passed in argv"
fi
if grep -q 'cert.pem\|key.pem\|apikey' "$ROOT/package/system/syncthing/syncthing.mk"; then
	fail "the package ships identity material"
fi

work=$(mktemp -d)
checker=$SRC/cmd/zlyme-bcrypt-check
serve_pid=
cleanup() {
	if [ -n "$serve_pid" ]; then
		kill "$serve_pid" 2>/dev/null || true
		wait "$serve_pid" 2>/dev/null || true
	fi
	rm -rf "$checker" "$work"
}
trap cleanup EXIT

mkdir -p "$checker"
cat > "$checker/main.go" << 'EOF'
package main

import (
	"bytes"
	"io"
	"os"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	hash, err := os.ReadFile(os.Args[1])
	if err != nil {
		os.Exit(2)
	}
	pass, err := io.ReadAll(os.Stdin)
	if err != nil {
		os.Exit(2)
	}
	pass = bytes.TrimRight(pass, "\r\n")
	if bcrypt.CompareHashAndPassword(bytes.TrimSpace(hash), pass) != nil {
		os.Exit(1)
	}
}
EOF
(
	cd "$SRC"
	go build -mod=vendor -o "$work/bcrypt-check" ./cmd/zlyme-bcrypt-check
)

mkdir -p "$work/bin" "$work/cfg"
printf '%s\n' "ZLYME_CFG=$work/cfg" > "$work/zlyme.conf"
export ZLYME_CONF="$work/zlyme.conf"
export ZLYME_SYNCTHING="$work/bin/syncthing"
export PATH="$work/bin:$PATH"

cat > "$work/bin/zlyme-ctl" << 'EOF'
#!/bin/sh
set -eu
case "${1:-}" in
	want)
		[ "${ZLYME_WANT_SYNCTHING:-0}" = 1 ]
		;;
	*)
		exit 0
		;;
esac
EOF

cat > "$work/bin/start-stop-daemon" << 'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "${ZLYME_SYNCTHING_DAEMON_LOG:?}"
exit 0
EOF

cat > "$work/bin/syncthing" << EOF
#!/bin/sh
set -eu
printf '%s\\n' "\$*" >> "\${ZLYME_SYNCTHING_ARGV_LOG:?}"
case " \$* " in
	*" --gui-password=zlyme "*|*" --gui-password zlyme "*)
		printf '%s\\n' "password in argv" >> "\${ZLYME_SYNCTHING_ARGV_LOG:?}"
		exit 1
		;;
esac
exec "$REAL" "\$@"
EOF
chmod 0755 "$work/bin/zlyme-ctl" "$work/bin/start-stop-daemon" "$work/bin/syncthing"

daemon_log=$work/daemon.log
argv_log=$work/argv.log
export ZLYME_SYNCTHING_DAEMON_LOG="$daemon_log"
export ZLYME_SYNCTHING_ARGV_LOG="$argv_log"
: > "$daemon_log"
: > "$argv_log"

password_of() {
	awk '
		BEGIN { in_gui = 0 }
		/<gui[ >]/ { in_gui = 1 }
		in_gui && /<\/gui>/ { in_gui = 0 }
		in_gui && match($0, /<password>[^<]*<\/password>/) {
			s = substr($0, RSTART, RLENGTH)
			gsub(/<\/?password>/, "", s)
			print s
			exit
		}
	' "$1"
}

user_of() {
	awk '
		BEGIN { in_gui = 0 }
		/<gui[ >]/ { in_gui = 1 }
		in_gui && /<\/gui>/ { in_gui = 0 }
		in_gui && match($0, /<user>[^<]*<\/user>/) {
			s = substr($0, RSTART, RLENGTH)
			gsub(/<\/?user>/, "", s)
			print s
			exit
		}
	' "$1"
}

device_of() {
	awk '
		match($0, /<device id="[A-Z0-9-]+"/) {
			s = substr($0, RSTART + 12, RLENGTH - 13)
			if (s != "") { print s; exit }
		}
	' "$1"
}

apikey_of() {
	awk '
		match($0, /<apikey>[^<]*<\/apikey>/) {
			s = substr($0, RSTART, RLENGTH)
			gsub(/<\/?apikey>/, "", s)
			print s
			exit
		}
	' "$1"
}

hash_matches() {
	_file=$1
	_pass=$2
	_hash=$work/hash.txt
	password_of "$_file" > "$_hash"
	printf '%s\n' "$_pass" | "$work/bcrypt-check" "$_hash"
}

# Disabled: no config, no listener.
export ZLYME_WANT_SYNCTHING=0
"$INIT" start
[ ! -f "$work/cfg/syncthing/config.xml" ] || fail "disabled start created a config"
[ ! -s "$daemon_log" ] || fail "disabled start launched the listener"
[ ! -s "$argv_log" ] || fail "disabled start ran syncthing"

# Fresh install.
export ZLYME_WANT_SYNCTHING=1
: > "$daemon_log"
: > "$argv_log"
"$INIT" start
cfg=$work/cfg/syncthing/config.xml
[ -f "$cfg" ] || fail "fresh start did not write config.xml"
[ -f "$work/cfg/syncthing/cert.pem" ] || fail "fresh start did not write a certificate"
[ -f "$work/cfg/syncthing/key.pem" ] || fail "fresh start did not write a key"
[ "$(user_of "$cfg")" = zlyme ] || fail "fresh user is not zlyme"
hash_matches "$cfg" zlyme || fail "fresh password does not verify as zlyme"
if grep -q '<password>zlyme</password>' "$cfg"; then
	fail "fresh password is stored in plaintext"
fi
grep -q 'generate' "$argv_log" || fail "fresh start did not generate"
grep -q -- '--gui-password=-' "$argv_log" || fail "generate did not read the password from stdin"
if grep -q 'password in argv' "$argv_log"; then
	fail "generate recorded the password in argv"
fi
grep -q '0.0.0.0:8384' "$daemon_log" || fail "listener was not requested on 0.0.0.0:8384"
id1=$(device_of "$cfg")
key1=$(apikey_of "$cfg")
[ -n "$id1" ] || fail "fresh device id is empty"
[ -n "$key1" ] || fail "fresh api key is empty"

# A second device is not the same identity.
home2=$(mktemp -d)
printf '%s\n' zlyme | "$REAL" --home="$home2" generate \
	--gui-user=zlyme --gui-password=- --no-port-probing >/dev/null
id2=$(device_of "$home2/config.xml")
key2=$(apikey_of "$home2/config.xml")
hash2=$(password_of "$home2/config.xml")
hash1=$(password_of "$cfg")
[ "$id1" != "$id2" ] || fail "two installs share a device id"
[ "$key1" != "$key2" ] || fail "two installs share an api key"
[ "$hash1" != "$hash2" ] || fail "two installs share a password hash"
rm -rf "$home2"

# Restart keeps the user's file byte for byte.
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
"$INIT" start
cmp -s "$work/before.xml" "$cfg" || fail "restart rewrote an authenticated config"
if grep -q generate "$argv_log"; then
	fail "restart ran generate"
fi
grep -q '0.0.0.0:8384' "$daemon_log" || fail "restart did not request the listener"

# A changed GUI login survives another start.
other=$(mktemp -d)
printf '%s\n' 'secret-pass' | "$REAL" --home="$other" generate \
	--gui-user=alice --gui-password=- --no-port-probing >/dev/null
other_user=$(user_of "$other/config.xml")
other_hash=$(password_of "$other/config.xml")
awk -v u="$other_user" -v p="$other_hash" '
	/<user>[^<]*<\/user>/ { sub(/<user>[^<]*<\/user>/, "<user>" u "</user>") }
	/<password>[^<]*<\/password>/ { sub(/<password>[^<]*<\/password>/, "<password>" p "</password>") }
	{ print }
' "$cfg" > "$work/changed.xml"
mv -f "$work/changed.xml" "$cfg"
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
"$INIT" start
cmp -s "$work/before.xml" "$cfg" || fail "start replaced a changed login"
[ "$(user_of "$cfg")" = alice ] || fail "changed user was not kept"
hash_matches "$cfg" secret-pass || fail "changed password does not verify"
if hash_matches "$cfg" zlyme; then
	fail "changed password still matches the default"
fi
rm -rf "$other"

# Missing GUI credentials: do not start, do not rewrite.
awk '
	/<user>[^<]*<\/user>/ { next }
	/<password>[^<]*<\/password>/ { next }
	{ print }
' "$cfg" > "$work/open.xml"
mv -f "$work/open.xml" "$cfg"
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
if "$INIT" start; then
	fail "missing credentials started"
fi
cmp -s "$work/before.xml" "$cfg" || fail "missing credentials rewrote the config"
[ ! -s "$daemon_log" ] || fail "missing credentials launched the listener"
if grep -q generate "$argv_log"; then
	fail "missing credentials ran generate"
fi

# Corrupt file: same refusal.
printf '%s\n' 'this is not configuration' > "$cfg"
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
if "$INIT" start; then
	fail "corrupt configuration started"
fi
cmp -s "$work/before.xml" "$cfg" || fail "corrupt configuration was replaced"
[ ! -s "$daemon_log" ] || fail "corrupt configuration launched the listener"

# Generate failure on a genuinely new home does not start the listener.
rm -rf "$work/cfg/syncthing"
cat > "$work/bin/syncthing" << 'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "${ZLYME_SYNCTHING_ARGV_LOG:?}"
exit 1
EOF
chmod 0755 "$work/bin/syncthing"
: > "$daemon_log"
: > "$argv_log"
if "$INIT" start; then
	fail "failed provisioning started"
fi
[ ! -s "$daemon_log" ] || fail "failed provisioning launched the listener"
[ ! -f "$work/cfg/syncthing/config.xml" ] || fail "failed provisioning left a config"

# The generated login works against the real listener. Wrong and missing
# passwords do not. This binds 127.0.0.1 only.
rm -f "$work/bin/syncthing"
home=$(mktemp -d)
printf '%s\n' zlyme | "$REAL" --home="$home" generate \
	--gui-user=zlyme --gui-password=- --no-port-probing >/dev/null
port=18484
"$REAL" --home="$home" serve --no-upgrade --no-browser \
	--gui-address="127.0.0.1:$port" >"$work/serve.log" 2>&1 &
serve_pid=$!
ready=0
i=0
while [ "$i" -lt 40 ]; do
	if grep -q 'GUI and API listening' "$work/serve.log"; then
		ready=1
		break
	fi
	i=$((i + 1))
	sleep 0.25
done
[ "$ready" = 1 ] || fail "listener did not report ready: $(cat "$work/serve.log")"
jar=$work/cookies
curl -s -c "$jar" -o /dev/null -u zlyme:zlyme "http://127.0.0.1:$port/"
short=$(awk '$6 ~ /^CSRF-Token-/ { sub(/^CSRF-Token-/, "", $6); print $6; exit }' "$jar")
token=$(awk -v id="$short" '$6 == "CSRF-Token-" id { print $7; exit }' "$jar")
if [ -z "$short" ] || [ -z "$token" ]; then
	fail "no CSRF cookie"
fi
code=$(curl -s -b "$jar" -u zlyme:zlyme \
	-H "X-CSRF-Token-$short: $token" \
	-o /dev/null -w '%{http_code}' \
	"http://127.0.0.1:$port/rest/system/status")
[ "$code" = 200 ] || fail "authenticated status returned $code"
bad=$(curl -s -o /dev/null -w '%{http_code}' -u zlyme:wrong \
	"http://127.0.0.1:$port/rest/system/status")
[ "$bad" = 403 ] || fail "wrong password returned $bad"
none=$(curl -s -o /dev/null -w '%{http_code}' \
	"http://127.0.0.1:$port/rest/system/status")
[ "$none" = 403 ] || fail "missing password returned $none"
kill "$serve_pid" 2>/dev/null || true
wait "$serve_pid" 2>/dev/null || true
serve_pid=
rm -rf "$home"

echo "syncthing auth ok"
