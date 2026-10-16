#!/bin/sh
# Per-ROM preference cleanup. Does not touch /storage.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CLEAN=$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh

fail() {
	echo "orphan prefs: $*" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sd1=$work/sd1
sd2=$work/sd2
usb=$work/media/USB
mkdir -p "$sd1/Roms/Game Boy (GB)/nested" "$sd1/Roms/NES (NES)" \
	"$sd2/Roms/Game Boy (GB)" "$usb/Roms/Game Boy (GB)"
printf x > "$sd1/Roms/Game Boy (GB)/nested/keep.gb"
printf x > "$sd1/Roms/NES (NES)/same.nes"
printf x > "$sd2/Roms/Game Boy (GB)/only.gb"
printf x > "$usb/Roms/Game Boy (GB)/stick.gb"
printf '%s\n' "$sd1" > "$work/libs"
prefs=$work/prefs
cat > "$prefs" << EOF
# keep
rom	GB	nested/keep.gb	performance	gambatte
rom	GB	nested/gone.gb	performance	gambatte
rom	GB	SD2/only.gb	quiet	
rom	GB	USB/stick.gb	performance	gambatte
folder	GB	nested	performance	
tag	GB		auto	
rom	NES	same.nes	performance	fceumm
rom	GB	nested/gone.gb	performance	gambatte
this is malformed
rom	GB		performance	
EOF

run() {
	ZLYME_CLEANUP_ROOT=$sd1 \
	ZLYME_SD2_ROOT=$sd2 \
	ZLYME_MEDIA_ROOT=$work/media \
	ZLYME_LIBRARIES_FILE=$work/libs \
	ZLYME_PREFS_FILE=$prefs \
	sh "$CLEAN" "$@"
}

out=$(run orphan-prefs --dry-run)
printf '%s\n' "$out" | head -n 1 | grep -qx 'COUNT=2' || fail "dry-run count: $out"
grep -q 'nested/gone.gb' "$prefs" || fail "dry-run rewrote the file"
before=$(wc -c < "$prefs")
run orphan-prefs >/dev/null
after=$(grep -c 'nested/gone.gb' "$prefs" || true)
[ "$after" = 0 ] || fail "orphan rom rows remained"
grep -q 'nested/keep.gb' "$prefs" || fail "existing rom was removed"
grep -q 'SD2/only.gb' "$prefs" || fail "absent SD2 row was removed"
grep -q 'USB/stick.gb' "$prefs" || fail "unmounted volume row was removed"
grep -q '^folder	GB	nested' "$prefs" || fail "folder row was removed"
grep -q '^tag	GB		auto' "$prefs" || fail "system row was removed"
grep -q 'same.nes' "$prefs" || fail "other system was removed"
grep -q 'this is malformed' "$prefs" || fail "malformed row was removed"
grep -q '^rom	GB		performance' "$prefs" || fail "blank rom path was removed"
[ "$(wc -c < "$prefs")" -lt "$before" ] || fail "file did not shrink"

# Second card present and the ROM is there: still kept.
printf '%s\n' "$sd1" "$sd2" > "$work/libs"
# Put the row back and a missing one.
printf '%s\n' 'rom	GB	SD2/only.gb	quiet	' >> "$prefs"
printf '%s\n' 'rom	GB	SD2/missing.gb	quiet	' >> "$prefs"
run orphan-prefs >/dev/null
grep -q 'SD2/only.gb' "$prefs" || fail "present SD2 rom was removed"
grep -q 'SD2/missing.gb' "$prefs" && fail "missing SD2 rom was kept"

# Mounted USB without the file, and the name is not a primary folder.
printf '%s\n' "$sd1" "$usb" > "$work/libs"
printf '%s\n' 'rom	GB	USB/stick.gb	performance	gambatte' >> "$prefs"
printf '%s\n' 'rom	GB	USB/gone.gb	performance	gambatte' >> "$prefs"
run orphan-prefs >/dev/null
grep -q 'USB/stick.gb' "$prefs" || fail "present USB rom was removed"
grep -q 'USB/gone.gb' "$prefs" && fail "missing USB rom was kept"

# Repeated dry-run does not change a clean file.
stamp=$(stat -c %Y "$prefs")
run orphan-prefs --dry-run >/dev/null
[ "$(stat -c %Y "$prefs")" = "$stamp" ] || fail "dry-run touched a clean file"
run orphan-prefs >/dev/null
[ "$(stat -c %Y "$prefs")" = "$stamp" ] || fail "a clean cleanup rewrote the file"

# The replacement is created beside the preference file.
mkdir -p "$work/notmp"
printf 'rom\tGB\tnested/also-gone.gb\tidle\t\n' >> "$prefs"
TMPDIR=$work/notmp run orphan-prefs >/dev/null
grep -q 'also-gone.gb' "$prefs" && fail "cleanup depended on TMPDIR"
find "$work/notmp" -type f | grep -q . && fail "cleanup wrote through TMPDIR"

# A failed rename leaves the previous file in place.
printf 'rom\tGB\tnested/later.gb\tidle\t\n' >> "$prefs"
before=$(cat "$prefs")
cat > "$work/mv" <<'EOF'
#!/bin/sh
last=
for arg in "$@"; do
	last=$arg
done
if [ "${ZLYME_MV_FAIL:-0}" = 1 ] && [ "$last" = "${ZLYME_PREFS_FILE:-}" ]; then
	exit 1
fi
exec /usr/bin/mv "$@"
EOF
chmod 755 "$work/mv"
if ZLYME_MV_FAIL=1 PATH="$work:$PATH" run orphan-prefs >/dev/null; then
	fail "preference rename failure was ignored"
fi
[ "$(cat "$prefs")" = "$before" ] || fail "failed rename replaced preferences"
grep -q 'later.gb' "$prefs" || fail "failed rename dropped the new row"

# A PATH that can run the cleanup, minus the tools a case is proving.
toolpath() {
	dest=$1
	shift
	mkdir -p "$dest"
	find "$dest" -mindepth 1 -exec rm -f {} +
	skip=" $* "
	for cmd in sh mkdir mktemp cat rm mv dirname basename grep find awk sed \
		cp ln ls stat readlink touch chmod tr wc head python3 flock; do
		case "$skip" in
			*" $cmd "*) continue ;;
		esac
		src=$(command -v "$cmd") || fail "host has no $cmd"
		ln -sf "$src" "$dest/$cmd"
	done
}

# Missing flock must not write. The row stays.
printf 'rom\tGB\tnested/no-flock.gb\tidle\t\n' >> "$prefs"
toolpath "$work/noflock" flock
if PATH="$work/noflock" run orphan-prefs >/dev/null; then
	fail "missing flock was accepted"
fi
grep -q 'no-flock.gb' "$prefs" || fail "missing flock still rewrote preferences"

# flock that cannot take the lock must not write.
printf 'rom\tGB\tnested/bad-flock.gb\tidle\t\n' >> "$prefs"
toolpath "$work/badflock"
rm -f "$work/badflock/flock"
cat > "$work/badflock/flock" << 'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$work/badflock/flock"
if PATH="$work/badflock" run orphan-prefs >/dev/null; then
	fail "failed flock was accepted"
fi
grep -q 'bad-flock.gb' "$prefs" || fail "failed flock still rewrote preferences"

# Python is required for the file fsync. Do not rename without it.
printf 'rom\tGB\tnested/no-py.gb\tidle\t\n' >> "$prefs"
toolpath "$work/nopy" python3
if PATH="$work/nopy" run orphan-prefs >/dev/null; then
	fail "missing python3 was accepted"
fi
grep -q 'no-py.gb' "$prefs" || fail "missing python3 still rewrote preferences"
find "$(dirname "$prefs")" -name '.zlyme-prefs.*' ! -name '.zlyme-prefs.lock' | grep -q . && fail "missing python3 left a temporary preference"

# A file fsync error leaves the previous file and removes the temporary.
printf 'rom\tGB\tnested/file-eio.gb\tidle\t\n' >> "$prefs"
mkdir -p "$work/site"
cat > "$work/site/sitecustomize.py" << 'PY'
import os
import stat
import time

_real = os.fsync

def fsync(fd):
    mode = os.environ.get("ZLYME_TEST_FSYNC", "")
    isdir = stat.S_ISDIR(os.fstat(fd).st_mode)
    if mode == "slow-file" and not isdir:
        open(os.environ["ZLYME_FSYNC_MARK"], "w").close()
        time.sleep(0.8)
    if mode == "file-eio" and not isdir:
        raise OSError(5, "fsync")
    if mode == "dir-einval" and isdir:
        raise OSError(22, "fsync")
    if mode == "dir-eio" and isdir:
        raise OSError(5, "fsync")
    return _real(fd)

os.fsync = fsync
PY
if PYTHONPATH="$work/site" ZLYME_TEST_FSYNC=file-eio run orphan-prefs >/dev/null; then
	fail "file fsync error was accepted"
fi
grep -q 'file-eio.gb' "$prefs" || fail "file fsync error still rewrote preferences"
find "$(dirname "$prefs")" -name '.zlyme-prefs.*' ! -name '.zlyme-prefs.lock' | grep -q . && fail "file fsync error left a temporary preference"

# Linux 7.2 exFAT implements directory fsync. EINVAL is the VFS result
# when a filesystem has no fsync operation. The renamed file stays.
printf 'rom\tGB\tnested/dir-einval.gb\tidle\t\n' >> "$prefs"
PYTHONPATH="$work/site" ZLYME_TEST_FSYNC=dir-einval run orphan-prefs >/dev/null
grep -q 'dir-einval.gb' "$prefs" && fail "unsupported directory fsync rejected the write"

# A real directory fsync error is reported after the rename. The new file stays.
printf 'rom\tGB\tnested/dir-eio.gb\tidle\t\n' >> "$prefs"
if PYTHONPATH="$work/site" ZLYME_TEST_FSYNC=dir-eio run orphan-prefs >/dev/null; then
	fail "directory fsync EIO was ignored"
fi
grep -q 'dir-eio.gb' "$prefs" && fail "directory fsync EIO rolled back a completed rename"

# The lock is held across the file fsync, not only around the rename.
printf 'rom\tGB\tnested/slow.gb\tidle\t\n' >> "$prefs"
PYTHONPATH="$work/site" ZLYME_TEST_FSYNC=slow-file ZLYME_FSYNC_MARK="$work/mark" \
	run orphan-prefs >/dev/null &
held_pid=$!
i=0
while [ ! -f "$work/mark" ] && [ "$i" -lt 50 ]; do
	i=$((i + 1))
	sleep 0.05
done
[ -f "$work/mark" ] || fail "slow fsync did not start"
if flock -n "$(dirname "$prefs")/.zlyme-prefs.lock" true; then
	fail "preference lock was not held during the write"
fi
wait "$held_pid"
grep -q 'slow.gb' "$prefs" && fail "locked write did not remove the orphan"

echo "orphan prefs ok"
