#!/bin/sh
# PortMaster's GUI transcript follows ZLYME_PAK_LOG, not LOGS_PATH alone.
set -eu
# shellcheck disable=SC1007
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LAUNCH=$ROOT/package/system/portmaster/portmaster-launch

fail() {
	echo "portmaster log: $*" >&2
	exit 1
}

work=$(mktemp -d)
tmp_log=/tmp/portmaster.log
if [ -e "$tmp_log" ]; then
	cp -a "$tmp_log" "$work/tmp-log-save"
fi
restore() {
	if [ -e "$work/tmp-log-save" ]; then
		cp -a "$work/tmp-log-save" "$tmp_log"
	else
		rm -f "$tmp_log"
	fi
	rm -rf "$work"
}
trap restore EXIT

root=$work/tree/PortMaster
mkdir -p "$root" "$work/ports" "$work/bin"
cat > "$work/bin/prepare" << 'EOF'
#!/bin/sh
exit 0
EOF
cat > "$work/bin/rootbin" << EOF
#!/bin/sh
[ "\${1:-}" = export ] || exit 1
printf '%s\n' "HM_TOOLS_DIR=$work/tree" "HM_PORTS_DIR=$work/ports" "HM_SCRIPTS_DIR=$work/ports"
EOF
chmod 0755 "$work/bin/prepare" "$work/bin/rootbin"

cat > "$work/bin/ok" << 'EOF'
#!/bin/sh
echo "gui-ok"
exit 0
EOF
cat > "$work/bin/bad" << 'EOF'
#!/bin/sh
echo "Error: synthetic"
exit 1
EOF
chmod 0755 "$work/bin/ok" "$work/bin/bad"

run() {
	label=$1
	pug=$2
	logs=$3
	pak=$4
	out=$work/$label.out
	err=$work/$label.err
	if [ -n "$pak" ]; then
		ZLYME_PAK_LOG=$pak
		export ZLYME_PAK_LOG
	else
		unset ZLYME_PAK_LOG
	fi
	set +e
	ZLYME_PM_NO_SLEEP=1 \
	ZLYME_PM_PREPARE=$work/bin/prepare \
	ZLYME_PM_ROOT_BIN=$work/bin/rootbin \
	ZLYME_PM_PUGWASH=$pug \
	LOGS_PATH=$logs \
		"$LAUNCH" >"$out" 2>"$err"
	st=$?
	set -e
	unset ZLYME_PAK_LOG
	printf '%s\n' "$st"
}

off=$work/off-logs
on=$work/on-logs
mkdir -p "$off" "$on"
printf '%s\n' SENTINEL > "$off/portmaster.txt"
sentinel=$(cksum "$off/portmaster.txt")

rm -f "$tmp_log"
st=$(run off-ok "$work/bin/ok" "$off" "")
[ "$st" -eq 0 ] || fail "logs off success exited $st"
grep -q 'gui-ok' "$tmp_log" || fail "logs off success missed the tmp transcript"
ck=$(cksum "$off/portmaster.txt")
[ "$ck" = "$sentinel" ] || fail "logs off success wrote a persistent transcript"
[ ! -s "$work/off-ok.out" ] || fail "logs off success printed gui output"

rm -f "$tmp_log"
st=$(run off-bad "$work/bin/bad" "$off" "")
[ "$st" -ne 0 ] || fail "logs off failure exited 0"
grep -q 'Error: synthetic' "$tmp_log" || fail "logs off failure missed the tmp transcript"
grep -q 'portmaster exit' "$tmp_log" || fail "logs off failure missed the exit line"
grep -q 'Error: synthetic' "$work/off-bad.out" || fail "logs off failure hid the on-screen error"
ck=$(cksum "$off/portmaster.txt")
[ "$ck" = "$sentinel" ] || fail "logs off failure wrote a persistent transcript"

printf '%s\n' SENTINEL > "$tmp_log"
tmp_sentinel=$(cksum "$tmp_log")
st=$(run on-ok "$work/bin/ok" "$on" "$work/pak.log")
[ "$st" -eq 0 ] || fail "logs on success exited $st"
grep -q 'gui-ok' "$on/portmaster.txt" || fail "logs on success missed portmaster.txt"
ck=$(cksum "$tmp_log")
[ "$ck" = "$tmp_sentinel" ] || fail "logs on success wrote /tmp/portmaster.log"
[ ! -s "$work/on-ok.out" ] || fail "logs on success printed gui output"

st=$(run on-bad "$work/bin/bad" "$on" "$work/pak.log")
[ "$st" -ne 0 ] || fail "logs on failure exited 0"
grep -q 'Error: synthetic' "$on/portmaster.txt" || fail "logs on failure missed portmaster.txt"
grep -q 'portmaster exit' "$on/portmaster.txt" || fail "logs on failure missed the exit line"
grep -q 'Error: synthetic' "$work/on-bad.out" || fail "logs on failure hid the on-screen error"
ck=$(cksum "$tmp_log")
[ "$ck" = "$tmp_sentinel" ] || fail "logs on failure wrote /tmp/portmaster.log"

cat > "$work/bin/fat" << 'EOF'
#!/bin/sh
dd if=/dev/zero bs=1024 count=1100 2>/dev/null
printf '%s\n' 'Error: synthetic'
exit 1
EOF
chmod 0755 "$work/bin/fat"
st=$(run on-fat "$work/bin/fat" "$on" "$work/pak.log")
[ "$st" -ne 0 ] || fail "long transcript exited 0"
grep -q 'Error: synthetic' "$on/portmaster.txt" || fail "long transcript dropped the error"
grep -q 'portmaster exit' "$on/portmaster.txt" || fail "long transcript dropped the exit line"
grep -q 'Error: synthetic' "$work/on-fat.out" || fail "long transcript hid the on-screen error"
_pmsz=$(wc -c < "$on/portmaster.txt" | tr -d ' ')
[ "$_pmsz" -le 1048640 ] || fail "long transcript stayed $_pmsz bytes"

# The last matching line can sit before the trimmed tail. The screen
# still shows it. The kept file is the tail.
cat > "$work/bin/buried" << 'EOF'
#!/bin/sh
printf '%s\n' 'Error: buried'
dd if=/dev/zero bs=1024 count=1100 2>/dev/null | tr '\0' 'x'
printf '\n%s\n' 'tail-only'
exit 1
EOF
chmod 0755 "$work/bin/buried"
st=$(run on-buried "$work/bin/buried" "$on" "$work/pak.log")
[ "$st" -ne 0 ] || fail "buried error exited 0"
grep -q 'Error: buried' "$work/on-buried.out" || fail "buried error was dropped from the screen"
grep -q 'tail-only' "$on/portmaster.txt" || fail "buried error dropped the tail"
_pmsz=$(wc -c < "$on/portmaster.txt" | tr -d ' ')
[ "$_pmsz" -le 1048640 ] || fail "buried transcript stayed $_pmsz bytes"

# A reboot loop that dies in prepare still shortens the finished transcript.
cat > "$work/bin/prep2" << EOF
#!/bin/sh
n=0
[ -f "$work/prep-count" ] && n=\$(cat "$work/prep-count")
n=\$((n + 1))
printf '%s\n' "\$n" > "$work/prep-count"
if [ "\$n" -ge 2 ]; then
	echo prepare-broke >&2
	exit 1
fi
exit 0
EOF
cat > "$work/bin/rebooter" << EOF
#!/bin/sh
dd if=/dev/zero bs=1024 count=1100 2>/dev/null | tr '\0' 'x'
printf '\n%s\n' 'END-MARK'
touch "$root/.pugwash-reboot"
exit 0
EOF
chmod 0755 "$work/bin/prep2" "$work/bin/rebooter"
set +e
ZLYME_PM_NO_SLEEP=1 \
ZLYME_PM_PREPARE=$work/bin/prep2 \
ZLYME_PM_ROOT_BIN=$work/bin/rootbin \
ZLYME_PM_PUGWASH=$work/bin/rebooter \
ZLYME_PAK_LOG=$work/pak.log \
LOGS_PATH=$on \
	"$LAUNCH" >"$work/on-reboot.out" 2>"$work/on-reboot.err"
st=$?
set -e
[ "$st" -ne 0 ] || fail "prepare failure after reboot exited 0"
grep -q 'prepare-broke' "$work/on-reboot.out" || fail "prepare failure hid its own error"
grep -q 'END-MARK' "$on/portmaster.txt" || fail "reboot transcript dropped the tail"
_pmsz=$(wc -c < "$on/portmaster.txt" | tr -d ' ')
[ "$_pmsz" -le 1048576 ] || fail "reboot transcript stayed $_pmsz bytes"

# The GUI still starts when the transcript cannot be opened.
closed=$work/closed-logs
mkdir -p "$closed"
chmod 555 "$closed"
rm -f "$tmp_log"
st=$(run closed-ok "$work/bin/ok" "$closed" "$work/pak.log")
chmod 755 "$closed"
[ "$st" -eq 0 ] || fail "unwritable transcript exited $st"
grep -q 'gui-ok' "$work/closed-ok.out" || fail "unwritable transcript skipped the GUI"

# pugwash failed and the transcript could not be opened. The wrapper
# still returns pugwash's status and still shows a failure.
cat > "$work/bin/bad-open" << 'EOF'
#!/bin/sh
echo "Error: closed"
exit 1
EOF
chmod 0755 "$work/bin/bad-open"
chmod 555 "$closed"
st=$(run closed-bad "$work/bin/bad-open" "$closed" "$work/pak.log")
chmod 755 "$closed"
[ "$st" -eq 1 ] || fail "unwritable failure exited $st"
grep -q 'PortMaster failed' "$work/closed-bad.out" || fail "unwritable failure hid the status"

# A successful GUI that wrote more than 1 MiB is shortened after it returns.
cat > "$work/bin/ok-fat" << 'EOF'
#!/bin/sh
printf '%s\n' 'HEAD-OK'
dd if=/dev/zero bs=1024 count=1100 2>/dev/null | tr '\0' 'x'
printf '\n%s\n' 'KEEP-OK'
exit 0
EOF
chmod 0755 "$work/bin/ok-fat"
st=$(run on-ok-fat "$work/bin/ok-fat" "$on" "$work/pak.log")
[ "$st" -eq 0 ] || fail "long success exited $st"
grep -q 'KEEP-OK' "$on/portmaster.txt" || fail "long success dropped the tail"
grep -q 'HEAD-OK' "$on/portmaster.txt" && fail "long success kept the old head"
_pmsz=$(wc -c < "$on/portmaster.txt" | tr -d ' ')
[ "$_pmsz" -le 1048576 ] || fail "long success stayed $_pmsz bytes"
[ ! -s "$work/on-ok-fat.out" ] || fail "long success printed gui output"

echo "portmaster log ok"
