#!/bin/sh
# PPSSPP save binds are released by pak-launch, not by the exec'd shell.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "ppsspp-binds: $*" >&2
	exit 1
}
psp=$ROOT/package/system/nextui/paks/Emus/PSP.pak/launch.sh
pak=$ROOT/package/system/nextui/zlyme/pak-launch.sh
if grep -E '^[[:space:]]*trap[[:space:]]' "$psp"; then
	fail "PSP.pak still unmounts from an EXIT trap"
fi
grep -q 'exec PPSSPPSDL' "$psp" || fail "PSP.pak no longer execs PPSSPPSDL"
awk '
	/^run_pak_cmd\(\)/ { on = 1 }
	on && $1 == "wait" { saw_wait = 1 }
	on && /ppsspp_bind_release/ && saw_wait { saw_release = 1 }
	on && /^}/ { exit }
	END { exit saw_release ? 0 : 1 }
' "$pak" || fail "the session does not release PPSSPP binds after wait"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bin=$work/bin
mkdir -p "$bin" \
	"$work/saves/PSP/SAVEDATA" "$work/saves/PSP/PPSSPP_STATE" \
	"$work/card/.config/ppsspp/PSP/SAVEDATA" \
	"$work/card/.config/ppsspp/PSP/PPSSPP_STATE" \
	"$work/card/.config/ppsspp/PSP/SYSTEM"
printf '%s\n' '[SystemParam]' > "$work/card/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
: > "$work/rom.iso"
mount_log=$work/mount.log
umount_log=$work/umount.log
: > "$mount_log"
: > "$umount_log"
cat > "$bin/mount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_TEST_MOUNT_LOG"
case " $* " in
	*" --fail "*) exit 1 ;;
esac
exit 0
EOF
cat > "$bin/umount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_TEST_UMOUNT_LOG"
if [ "${ZLYME_TEST_UMOUNT_BUSY:-}" = 1 ]; then
	exit 1
fi
exit 0
EOF
cat > "$bin/mountpoint" << 'EOF'
#!/bin/sh
if [ "$1" = -q ]; then
	shift
fi
grep -F -q -- "$1" "$ZLYME_TEST_MOUNT_LOG"
EOF
cat > "$bin/PPSSPPSDL" << 'EOF'
#!/bin/sh
if [ -s "$ZLYME_TEST_UMOUNT_LOG" ]; then
	echo unmounted-during-play > "$ZLYME_TEST_MARK"
	exit 3
fi
echo played > "$ZLYME_TEST_MARK"
exit 9
EOF
chmod 0755 "$bin/mount" "$bin/umount" "$bin/mountpoint" "$bin/PPSSPPSDL"
record=$work/binds
run_psp() {
	PATH=$bin:/usr/bin:/bin \
		ZLYME_TEST_MOUNT_LOG=$mount_log \
		ZLYME_TEST_UMOUNT_LOG=$umount_log \
		ZLYME_TEST_MARK=$work/mark \
		ZLYME_PPSSPP_BINDS=$record \
		XDG_CONFIG_HOME=$work/card/.config \
		SDCARD_PATH=$work/card \
		USERDATA_PATH=$work/home \
		BIOS_PATH=$work/bios \
		SAVES_PATH=$work/saves \
		sh "$psp" "$work/rom.iso"
}

rm -f "$work/mark"
set +e
run_psp
st=$?
set -e
[ "$st" = 9 ] || fail "PPSSPP exit status was not preserved ($st)"
grep -qx played "$work/mark" || fail "PPSSPP did not run while the binds were held"
[ ! -s "$umount_log" ] || fail "the launcher unmounted PPSSPP before it exited"
grep -qx -- "$work/card/.config/ppsspp/PSP/SAVEDATA" "$record" || fail "SAVEDATA was not recorded"
grep -qx -- "$work/card/.config/ppsspp/PSP/PPSSPP_STATE" "$record" || fail "PPSSPP_STATE was not recorded"
[ "$(grep -c -- '--bind' "$mount_log")" = 2 ] || fail "the first launch did not bind both directories"

# A second launch must not stack another bind over a live destination.
run_psp >/dev/null || true
[ "$(grep -c -- '--bind' "$mount_log")" = 2 ] || fail "a repeated launch stacked another bind"

# shellcheck disable=SC1090
. "$pak"
PATH=$bin:/usr/bin:/bin \
	ZLYME_TEST_MOUNT_LOG=$mount_log \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	ZLYME_PPSSPP_BINDS=$record \
	ppsspp_bind_release
grep -qx -- "$work/card/.config/ppsspp/PSP/SAVEDATA" "$umount_log" || fail "SAVEDATA was not released"
grep -qx -- "$work/card/.config/ppsspp/PSP/PPSSPP_STATE" "$umount_log" || fail "PPSSPP_STATE was not released"
[ ! -e "$record" ] || fail "a released PPSSPP record was kept"

# Partial failure records only the bind that succeeded.
: > "$mount_log"
: > "$umount_log"
cat > "$bin/mount" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$ZLYME_TEST_MOUNT_LOG"
case "$*" in
	*PPSSPP_STATE*) exit 1 ;;
esac
exit 0
EOF
chmod 0755 "$bin/mount"
run_psp >/dev/null || true
grep -qx -- "$work/card/.config/ppsspp/PSP/SAVEDATA" "$record" || fail "the successful bind was not recorded"
if grep -q PPSSPP_STATE "$record"; then
	fail "a failed bind was recorded"
fi
PATH=$bin:/usr/bin:/bin \
	ZLYME_TEST_MOUNT_LOG=$mount_log \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	ZLYME_PPSSPP_BINDS=$record \
	ppsspp_bind_release
grep -qx -- "$work/card/.config/ppsspp/PSP/SAVEDATA" "$umount_log" || fail "the partial bind was not released"
if grep -q PPSSPP_STATE "$umount_log"; then
	fail "the failed bind was unmounted"
fi

# Unowned paths, including library roots, are not unmounted.
printf '%s\n' /storage /mnt/sd2 /boot /tmp/not-ppsspp \
	"$work/card/.config/../ppsspp/PSP/SAVEDATA" > "$record"
: > "$umount_log"
PATH=$bin:/usr/bin:/bin \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	ZLYME_PPSSPP_BINDS=$record \
	ppsspp_bind_release
[ ! -s "$umount_log" ] || fail "an unowned path was unmounted"
[ ! -e "$record" ] || fail "invalid PPSSPP records were kept"

# A busy owned mount stays recorded.
printf '%s\n' "$work/card/.config/ppsspp/PSP/SAVEDATA" > "$record"
printf '%s\n' "--bind $work/saves/PSP/SAVEDATA $work/card/.config/ppsspp/PSP/SAVEDATA" > "$mount_log"
: > "$umount_log"
PATH=$bin:/usr/bin:/bin \
	ZLYME_TEST_MOUNT_LOG=$mount_log \
	ZLYME_TEST_UMOUNT_LOG=$umount_log \
	ZLYME_TEST_UMOUNT_BUSY=1 \
	ZLYME_PPSSPP_BINDS=$record \
	ppsspp_bind_release
grep -qx -- "$work/card/.config/ppsspp/PSP/SAVEDATA" "$umount_log" || fail "a busy bind was not attempted"
grep -qx -- "$work/card/.config/ppsspp/PSP/SAVEDATA" "$record" || fail "a busy bind record was dropped"

echo "ppsspp binds ok"
