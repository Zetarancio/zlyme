#!/bin/sh
# Host tests for the SSH password helper. Nothing is mounted and sshd
# is not started. OpenSSH is not asked to log in.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-ssh-auth"
RESET="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-reset"
S50="$ROOT/board/my355/fsoverlay/etc/init.d/S50sshd"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cfg=$work/storage/.config
mkdir -p "$cfg/zlyme" "$work/run" "$work/bin"
printf '%s\n' \
	'root:!:0:0:99999:7:::' \
	'daemon:*:19000:0:99999:7:::' \
	'messagebus:!:19000:0:99999:7:::' \
	> "$work/shadow.src"
cp "$work/shadow.src" "$work/shadow.orig-saved"

cat > "$work/bin/openssl-fake" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ARGV_LOG:?}"
if [ -r "/proc/$PPID/cmdline" ]; then
	tr '\0' ' ' < "/proc/$PPID/cmdline" >> "${ARGV_LOG:?}"
	printf '\n' >> "${ARGV_LOG:?}"
fi
cat > "${STDIN_LOG:?}"
if [ -n "${OPENSSL_SLEEP:-}" ]; then
	sleep "$OPENSSL_SLEEP"
fi
printf '%s\n' '$6$testsalt$fakecryptfakecryptfakecrypt'
EOF
chmod 0755 "$work/bin/openssl-fake"
# The helper calls `openssl`, not openssl-fake.
ln -s openssl-fake "$work/bin/openssl"

fail() {
	printf 'FAIL %s\n' "$1" >&2
	exit 1
}

shadow_out() {
	printf '%s\n' "$work/run/shadow"
}

auth() {
	env \
		ZLYME_CFG="$cfg" \
		ZLYME_SSH_RUN="$work/run" \
		ZLYME_SSH_SHADOW_SRC="$work/shadow.src" \
		ZLYME_SSH_NO_MOUNT=1 \
		ZLYME_SSH_RELOAD_LOG="$work/reload.log" \
		"$BIN" "$@"
}

root_field() {
	line=$(grep '^root:' "$work/run/shadow")
	rest=${line#*:}
	printf '%s' "${rest%%:*}"
}

others_match() {
	grep -v '^root:' "$work/run/shadow" > "$work/out.others"
	grep -v '^root:' "$work/shadow.src" > "$work/src.others"
	cmp "$work/out.others" "$work/src.others"
}

verify() {
	vpw=$1
	vfield=$2
	vbody=${vfield#\$6\$}
	vsalt=${vbody%%\$*}
	vgot=$(printf '%s' "$vpw" | openssl passwd -6 -salt "$vsalt" -stdin)
	[ "$vgot" = "$vfield" ]
}

mounted() {
	awk '$2 == "/etc/shadow" { found = 1 } END { exit !found }' /proc/mounts
}

if mounted; then
	fail "host /etc/shadow is already bind-mounted"
fi

# Fresh default: locked squashfs field becomes an empty password.
auth apply
[ "$(root_field)" = "" ] || fail "fresh root field is not empty"
grep -q '^root::0:0:99999:7:::$' "$work/run/shadow" || fail "fresh root line"
others_match || fail "fresh apply changed another account"
: > "$work/got"
auth get > "$work/got"
[ ! -s "$work/got" ] || fail "fresh get is not empty"
[ ! -e "$cfg/zlyme/ssh.password" ] || fail "fresh install wrote a password file"

# Password creation, including spaces and shell metacharacters.
pw='a b!c$d`e'"'"'(ok)'
: > "$work/reload.log"
printf '%s' "$pw" | auth set
got=$(auth get)
[ "$got" = "$pw" ] || fail "get does not match the stored password"
field=$(root_field)
verify "$pw" "$field" || fail "created hash does not match"
others_match || fail "create changed another account"
[ "$(grep -c '^reload$' "$work/reload.log")" = 1 ] || fail "create did not reload sshd"
mode=$(stat -c '%a' "$cfg/zlyme/ssh.password")
[ "$mode" = 600 ] || fail "password file mode $mode"

# Modification.
: > "$work/reload.log"
pw2='second value'
printf '%s' "$pw2" | auth set
got=$(auth get)
[ "$got" = "$pw2" ] || fail "modified password"
field2=$(root_field)
verify "$pw2" "$field2" || fail "modified hash"
if verify "$pw" "$field2"; then
	fail "old password still matches"
fi
[ "$(grep -c '^reload$' "$work/reload.log")" = 1 ] || fail "modify did not reload"

# Skip-reload does not HUP, and does not restart the init script.
before=$(grep -c '^reload$' "$work/reload.log")
ZLYME_SSH_SKIP_RELOAD=1 auth apply
after=$(grep -c '^reload$' "$work/reload.log")
[ "$before" = "$after" ] || fail "skip-reload still reloaded"
grep -q 'S50sshd' "$BIN" && fail "helper restarts S50sshd"

# Removal.
: > "$work/reload.log"
auth clear
[ ! -e "$cfg/zlyme/ssh.password" ] || fail "clear left the password file"
: > "$work/got"
auth get > "$work/got"
[ ! -s "$work/got" ] || fail "cleared get is not empty"
[ "$(root_field)" = "" ] || fail "cleared shadow is not empty"
others_match || fail "clear changed another account"
[ "$(grep -c '^reload$' "$work/reload.log")" = 1 ] || fail "clear did not reload"

# Malformed input must not replace a good password.
printf '%s' "$pw2" | auth set
cp "$work/run/shadow" "$work/shadow.good"
cp "$cfg/zlyme/ssh.password" "$work/pass.good"
try_bad() {
	label=$1
	raw=$2
	err=$work/err
	if printf '%s' "$raw" | auth set >"$work/out" 2>"$err"; then
		fail "$label was accepted"
	fi
	[ "$(cat "$err")" = rejected ] || fail "$label stderr"
	cmp "$work/pass.good" "$cfg/zlyme/ssh.password" || fail "$label changed the file"
	cmp "$work/shadow.good" "$work/run/shadow" || fail "$label changed the shadow"
	if grep -F -q "$raw" "$err"; then
		fail "$label leaked into stderr"
	fi
}
try_bad newline 'bad
pass'
python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).write_bytes(b"ab\x00cd")' "$work/nulpw"
err=$work/err
if auth set < "$work/nulpw" >"$work/out" 2>"$err"; then
	fail "NUL was accepted"
fi
[ "$(cat "$err")" = rejected ] || fail "NUL stderr"
cmp "$work/pass.good" "$cfg/zlyme/ssh.password" || fail "NUL changed the file"
if grep -F -q 'ab' "$err"; then
	fail "NUL leaked into stderr"
fi
long=$(python3 -c 'print("x"*257, end="")')
try_bad overlong "$long"
ok256=$(python3 -c 'print("y"*256, end="")')
printf '%s' "$ok256" | auth set
[ "$(auth get)" = "$ok256" ] || fail "256-byte password"
verify "$ok256" "$(root_field)" || fail "256-byte hash"

# Command text is stored, not executed.
printf '%s' "$pw2" | auth set
inj='$(touch '"$work"'/pwned); `touch '"$work"'/pwned2`'
printf '%s' "$inj" | auth set
[ ! -e "$work/pwned" ] || fail "command substitution ran"
[ ! -e "$work/pwned2" ] || fail "backticks ran"
[ "$(auth get)" = "$inj" ] || fail "injection text was not stored"
verify "$inj" "$(root_field)" || fail "injection hash"
grep -q 'eval ' "$BIN" && fail "helper uses eval"

# Argument disclosure. The fake openssl records argv and sleeps.
: > "$work/argv.log"
: > "$work/stdin.log"
secret='not-in-argv'
cat > "$work/secret.in" <<EOF
$secret
EOF
ARGV_LOG="$work/argv.log" STDIN_LOG="$work/stdin.log" OPENSSL_SLEEP=1 \
	PATH="$work/bin:$PATH" \
	auth set < "$work/secret.in" >/dev/null &
setter=$!
found=0
i=0
while [ "$i" -lt 40 ]; do
	for cmdf in /proc/[0-9]*/cmdline; do
		[ -r "$cmdf" ] || continue
		line=$(tr '\0' ' ' < "$cmdf" || true)
		case "$line" in
			*openssl*)
				found=1
				if printf '%s' "$line" | grep -F -q "$secret"; then
					fail "openssl argv contains the password"
				fi
				;;
		esac
	done
	[ "$found" = 1 ] && break
	if ! kill -0 "$setter" 2>/dev/null; then
		break
	fi
	i=$((i + 1))
	sleep 0.05
done
wait "$setter"
[ "$found" = 1 ] || fail "did not observe openssl"
if grep -F -q "$secret" "$work/argv.log"; then
	fail "argv log contains the password"
fi
[ "$(cat "$work/stdin.log")" = "$secret" ] || fail "openssl did not receive stdin"
# The fake hash is not a real one. Put the real password back.
printf '%s' "$pw2" | auth set

# Persistence across a simulated reboot: /run is gone, the file stays.
rm -rf "$work/run"
mkdir -p "$work/run"
auth apply
[ "$(auth get)" = "$pw2" ] || fail "password did not survive reboot"
verify "$pw2" "$(root_field)" || fail "rebuilt hash"
others_match || fail "reboot apply changed another account"

# Settings reset and factory reset clear it and restore the empty field.
export ZLYME_RESET_ROOT="$work"
export ZLYME_CFG="$cfg"
export ZLYME_SSH_AUTH_BIN="$BIN"
export ZLYME_SSH_RUN="$work/run"
export ZLYME_SSH_SHADOW_SRC="$work/shadow.src"
export ZLYME_SSH_NO_MOUNT=1
export ZLYME_SSH_RELOAD_LOG="$work/reload.log"
"$RESET" settings
[ ! -e "$cfg/zlyme/ssh.password" ] || fail "settings reset left the password"
[ "$(root_field)" = "" ] || fail "settings reset left a hash"
others_match || fail "settings reset changed another account"
printf '%s' "$pw2" | auth set
"$RESET" factory
[ ! -e "$cfg/zlyme/ssh.password" ] || fail "factory reset left the password"
[ "$(root_field)" = "" ] || fail "factory reset left a hash"
others_match || fail "factory reset changed another account"
[ -f "$cfg/zlyme/factory-reset" ] || fail "factory marker missing"

apply_at=$(grep -n 'zlyme-ssh-auth apply' "$S50" | head -1 | cut -d: -f1)
call_at=$(grep -n 'run_sshd$' "$S50" | head -1 | cut -d: -f1)
[ -n "$apply_at" ] && [ -n "$call_at" ] || fail "S50sshd does not apply the password"
[ "$apply_at" -lt "$call_at" ] || fail "S50sshd applies the password after starting sshd"
grep -q 'ZLYME_SSH_SKIP_RELOAD=1' "$S50" || fail "S50sshd reloads from inside start"

if mounted; then
	fail "test bind-mounted /etc/shadow"
fi

printf 'ok\n'
