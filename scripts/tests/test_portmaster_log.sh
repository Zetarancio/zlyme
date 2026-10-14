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

echo "portmaster log ok"
