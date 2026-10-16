#!/bin/sh
# Phase 13E2. Syncthing 2.0.13 generate, then the init script.
# The listener check is on 127.0.0.1 with the host-built binary.
# It is not a Flip test.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
INIT=$ROOT/board/my355/fsoverlay/etc/init.d/S75syncthing
GUI=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-syncthing-gui
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
[ -x "$GUI" ] || fail "GUI parser is missing"
if grep -q 'awk' "$INIT"; then
	fail "init still scans config.xml with awk"
fi
if grep -q -- '--gui-password=zlyme' "$INIT"; then
	fail "initial password is passed in argv"
fi
if grep -q 'cert.pem\|key.pem\|apikey' "$ROOT/package/system/syncthing/syncthing.mk"; then
	fail "the package ships identity material"
fi

work=$(mktemp -d)
serve_pid=
src_dirs=$(find "$SRC" -type d | wc -l)
cleanup() {
	if [ -n "$serve_pid" ]; then
		kill "$serve_pid" 2>/dev/null || true
		wait "$serve_pid" 2>/dev/null || true
	fi
	rm -rf "$work"
}
trap cleanup EXIT
if [ -e "$SRC/cmd/zlyme-bcrypt-check" ]; then
	fail "pinned source already contains cmd/zlyme-bcrypt-check"
fi

# Isolated module. The pinned tree is not a build directory and is not deleted.
mod=$work/mod
crypto=$mod/xcrypto
mkdir -p "$crypto/bcrypt" "$crypto/blowfish"
cp "$SRC/vendor/golang.org/x/crypto/bcrypt/"*.go "$crypto/bcrypt/"
cp "$SRC/vendor/golang.org/x/crypto/blowfish/"*.go "$crypto/blowfish/"
rm -f "$crypto/bcrypt/"*_test.go "$crypto/blowfish/"*_test.go
cat > "$crypto/go.mod" << 'EOF'
module golang.org/x/crypto

go 1.24.0
EOF
cat > "$mod/go.mod" << 'EOF'
module zlyme.local/bcryptcheck

go 1.24.0

require golang.org/x/crypto v0.44.0

replace golang.org/x/crypto => ./xcrypto
EOF
cat > "$mod/main.go" << 'EOF'
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
	cd "$mod"
	GOSUMDB=off GOPROXY=off go build -o "$work/bcrypt-check" .
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
		case "${2:-}" in
			syncthing) [ "${ZLYME_WANT_SYNCTHING:-0}" = 1 ] ;;
			wifi) [ "${ZLYME_WIFI_WANT:-1}" = 1 ] ;;
			*) exit 1 ;;
		esac
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
export ZLYME_SYNCTHING_GUI="$GUI"
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

# A comment can contain a gui element that looks authenticated. The
# parsed document has no user and no password. Startup refuses it.
# About reports the same parse.
comment_body() {
	cat << 'EOF'
<configuration version="50">
  <!--
  <gui enabled="true" tls="false">
    <user>zlyme</user>
    <password>$2a$10$DEz.z2B2OovL1pa.dQl4bOTttxkPtRpq3timKQXpfpLDdcwxLCFyW</password>
    <authMode>ldap</authMode>
  </gui>
  -->
  <gui enabled="true" tls="false">
    <address>127.0.0.1:8384</address>
  </gui>
</configuration>
EOF
}

expect_about() {
	_got=$("$GUI" about "$1")
	_want=$2
	[ "$_got" = "$_want" ] || fail "about $(printf '%s' "$1" | wc -c) bytes: [$_got]"
}

comment_body > "$cfg"
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
if "$INIT" start; then
	fail "commented credentials started"
fi
cmp -s "$work/before.xml" "$cfg" || fail "commented credentials rewrote the config"
[ ! -s "$daemon_log" ] || fail "commented credentials launched the listener"
if grep -q generate "$argv_log"; then
	fail "commented credentials ran generate"
fi
expect_about "$cfg" "$(printf '%s\n' '(unavailable)' '(unavailable)')"
if "$GUI" ready "$cfg"; then
	fail "commented credentials passed the parser"
fi

# Two gui elements. One is authenticated. The document is ambiguous.
cat > "$cfg" << 'EOF'
<configuration>
  <gui>
    <user>zlyme</user>
    <password>$2a$10$DEz.z2B2OovL1pa.dQl4bOTttxkPtRpq3timKQXpfpLDdcwxLCFyW</password>
  </gui>
  <gui>
    <address>127.0.0.1:8384</address>
  </gui>
</configuration>
EOF
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
if "$INIT" start; then
	fail "duplicated gui started"
fi
cmp -s "$work/before.xml" "$cfg" || fail "duplicated gui rewrote the config"
[ ! -s "$daemon_log" ] || fail "duplicated gui launched the listener"
expect_about "$cfg" "$(printf '%s\n' '(unavailable)' '(unavailable)')"

cat > "$cfg" << 'EOF'
<configuration>
  <gui>
    <user>zlyme</user>
    <user>other</user>
    <password>$2a$10$DEz.z2B2OovL1pa.dQl4bOTttxkPtRpq3timKQXpfpLDdcwxLCFyW</password>
  </gui>
</configuration>
EOF
if "$GUI" ready "$cfg"; then
	fail "duplicated user passed the parser"
fi

printf '%s\n' '<configuration><gui><user>zlyme</user>' > "$cfg"
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
if "$INIT" start; then
	fail "malformed configuration started"
fi
cmp -s "$work/before.xml" "$cfg" || fail "malformed configuration was replaced"
[ ! -s "$daemon_log" ] || fail "malformed configuration launched the listener"

# LDAP is authentication with no local password. A comment is not.
cat > "$cfg" << 'EOF'
<configuration>
  <gui enabled="true">
    <authMode>ldap</authMode>
  </gui>
</configuration>
EOF
cp -a "$cfg" "$work/before.xml"
: > "$daemon_log"
: > "$argv_log"
"$INIT" start || fail "LDAP configuration did not start"
cmp -s "$work/before.xml" "$cfg" || fail "LDAP configuration was rewritten"
grep -q '0.0.0.0:8384' "$daemon_log" || fail "LDAP configuration did not request the listener"
if grep -q generate "$argv_log"; then
	fail "LDAP configuration ran generate"
fi

cat > "$cfg" << 'EOF'
<configuration>
  <!-- <authMode>ldap</authMode> -->
  <gui enabled="true">
    <address>127.0.0.1:8384</address>
  </gui>
</configuration>
EOF
if "$GUI" ready "$cfg"; then
	fail "LDAP inside a comment passed the parser"
fi

# A nonempty plaintext password enables auth in Syncthing 2.0.13.
# About does not print it.
cat > "$cfg" << 'EOF'
<configuration>
  <gui>
    <user>zlyme</user>
    <password>zlyme</password>
  </gui>
</configuration>
EOF
"$GUI" ready "$cfg" || fail "plaintext password was treated as disabled auth"
expect_about "$cfg" "$(printf '%s\n' 'zlyme' '(unavailable)')"

# The pinned binary, on loopback, treats the commented document as
# unauthenticated. The init script above refused that document.
open_home=$(mktemp -d)
printf '%s\n' zlyme | "$REAL" --home="$open_home" generate \
	--gui-user=zlyme --gui-password=- --no-port-probing >/dev/null
python3 - "$open_home/config.xml" << 'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
start = text.find("<gui")
end = text.find("</gui>")
if start < 0 or end < 0:
    raise SystemExit("generated config has no gui element")
end += len("</gui>")
repl = """<!--
<gui enabled="true" tls="false">
    <user>zlyme</user>
    <password>$2a$10$DEz.z2B2OovL1pa.dQl4bOTttxkPtRpq3timKQXpfpLDdcwxLCFyW</password>
</gui>
-->
<gui enabled="true" tls="false">
    <address>127.0.0.1:8384</address>
</gui>"""
path.write_text(text[:start] + repl + text[end:])
PY
if "$GUI" ready "$open_home/config.xml"; then
	fail "spliced commented config passed the parser"
fi
open_port=18485
"$REAL" --home="$open_home" serve --no-upgrade --no-browser \
	--gui-address="127.0.0.1:$open_port" >"$work/open.log" 2>&1 &
serve_pid=$!
open_ready=0
i=0
while [ "$i" -lt 40 ]; do
	if grep -q 'GUI and API listening' "$work/open.log"; then
		open_ready=1
		break
	fi
	i=$((i + 1))
	sleep 0.25
done
[ "$open_ready" = 1 ] || fail "open listener did not report ready: $(cat "$work/open.log")"
# Auth disabled still requires the CSRF cookie on /rest. No password is sent.
open_jar=$work/open-cookies
open_page=$(curl -s -c "$open_jar" -o /dev/null -w '%{http_code}' \
	"http://127.0.0.1:$open_port/")
[ "$open_page" = 200 ] || fail "unauthenticated GUI returned $open_page"
open_short=$(awk '$6 ~ /^CSRF-Token-/ { sub(/^CSRF-Token-/, "", $6); print $6; exit }' "$open_jar")
open_token=$(awk -v id="$open_short" '$6 == "CSRF-Token-" id { print $7; exit }' "$open_jar")
if [ -z "$open_short" ] || [ -z "$open_token" ]; then
	fail "unauthenticated GUI did not set a CSRF cookie"
fi
open_code=$(curl -s -b "$open_jar" -o /dev/null -w '%{http_code}' \
	-H "X-CSRF-Token-$open_short: $open_token" \
	"http://127.0.0.1:$open_port/rest/system/status")
[ "$open_code" = 200 ] || fail "unauthenticated status returned $open_code"
kill "$serve_pid" 2>/dev/null || true
wait "$serve_pid" 2>/dev/null || true
serve_pid=
rm -rf "$open_home"

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

now=$(find "$SRC" -type d | wc -l)
[ "$now" = "$src_dirs" ] || fail "pinned source tree changed: [$src_dirs] then [$now]"
[ ! -e "$SRC/cmd/zlyme-bcrypt-check" ] || fail "test wrote into the pinned source"

echo "syncthing auth ok"
