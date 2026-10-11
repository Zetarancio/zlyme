#!/bin/sh
# USB library mountpoints. Fake mount(8) and a mounts-file seam. No root mounts.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
bin=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

media=$work/media
devs=$work/dev
mkdir -p "$media" "$devs" "$work/bin" "$work/sys/class/block"
: > "$devs/sda1"
: > "$devs/sdb1"
: > "$work/mounts"
: > "$work/mount.log"
: > "$work/umount.log"

export ZLYME_STORAGE_MOUNTS="$work/mounts"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_STORAGE_MEDIA="$media"
export ZLYME_STORAGE_SD2="$work/sd2"
export ZLYME_STORAGE_DEV_ROOT="$devs"
export ZLYME_STORAGE_SYSFS="$work/sys"
export ZLYME_STORAGE_RUN="$work/run"
export ZLYME_MOUNTS_LIB="$ROOT/board/my355/fsoverlay/usr/share/zlyme/mounts.sh"
export ZLYME_STORAGE_PATH="$work/bin:/usr/bin:/bin"
export ZLYME_FAKE_MOUNT_LOG="$work/mount.log"
export ZLYME_FAKE_UMOUNT_LOG="$work/umount.log"

cat > "$work/bin/mount" << EOF
#!/bin/sh
exec python3 "$work/mount.py" "\$@"
EOF
cat > "$work/bin/umount" << EOF
#!/bin/sh
exec python3 "$work/umount.py" "\$@"
EOF
chmod 0755 "$work/bin/mount" "$work/bin/umount"

cat > "$work/mount.py" << 'PY'
import os
import sys

mounts = os.environ["ZLYME_STORAGE_MOUNTS"]
log = os.environ["ZLYME_FAKE_MOUNT_LOG"]

def decode(s):
    out = []
    i = 0
    n = len(s)
    while i < n:
        chunk = s[i + 1:i + 4]
        if (
            s[i] == "\\"
            and len(chunk) == 3
            and all(c in "01234567" for c in chunk)
        ):
            out.append(chr(int(chunk, 8)))
            i += 4
        else:
            out.append(s[i])
            i += 1
    return "".join(out)

def encode(s):
    out = []
    for ch in s:
        o = ord(ch)
        if ch in " \t\n\\" or o < 32 or o == 127:
            out.append("\\%03o" % o)
        else:
            out.append(ch)
    return "".join(out)

args = sys.argv[1:]
move = "--move" in args
pos = [arg for arg in args if not arg.startswith("-")]
if len(pos) < 2:
    sys.exit(1)
src, dest = pos[-2], pos[-1]
with open(log, "a", encoding="utf-8") as fh:
    fh.write(("move" if move else "mount") + "\t" + dest + "\n")
lines = []
if os.path.exists(mounts):
    with open(mounts, "r", encoding="utf-8") as fh:
        lines = fh.read().splitlines()
if move:
    replaced = False
    new = []
    for line in lines:
        parts = line.split()
        if not replaced and len(parts) >= 2 and decode(parts[1]) == src:
            new.append("%s %s fake rw 0 0" % (parts[0], encode(dest)))
            replaced = True
        else:
            new.append(line)
    if not replaced:
        new.append("%s %s fake rw 0 0" % (encode(src), encode(dest)))
    lines = new
else:
    lines.append("%s %s fake rw 0 0" % (encode(src), encode(dest)))
text = ("\n".join(lines) + "\n") if lines else ""
with open(mounts, "w", encoding="utf-8") as fh:
    fh.write(text)
PY

cat > "$work/umount.py" << 'PY'
import os
import sys

mounts = os.environ["ZLYME_STORAGE_MOUNTS"]
log = os.environ["ZLYME_FAKE_UMOUNT_LOG"]

def decode(s):
    out = []
    i = 0
    n = len(s)
    while i < n:
        chunk = s[i + 1:i + 4]
        if (
            s[i] == "\\"
            and len(chunk) == 3
            and all(c in "01234567" for c in chunk)
        ):
            out.append(chr(int(chunk, 8)))
            i += 4
        else:
            out.append(s[i])
            i += 1
    return "".join(out)

args = sys.argv[1:]
pos = [arg for arg in args if not arg.startswith("-")]
if not pos:
    sys.exit(1)
target = pos[-1]
with open(log, "a", encoding="utf-8") as fh:
    fh.write(target + "\n")
if os.environ.get("ZLYME_FAKE_UMOUNT_FAIL") == "1":
    sys.exit(1)
lines = []
if os.path.exists(mounts):
    with open(mounts, "r", encoding="utf-8") as fh:
        lines = fh.read().splitlines()
kept = []
removed = False
for line in lines:
    parts = line.split()
    if not removed and len(parts) >= 2 and decode(parts[1]) == target:
        removed = True
        continue
    kept.append(line)
text = ("\n".join(kept) + "\n") if kept else ""
with open(mounts, "w", encoding="utf-8") as fh:
    fh.write(text)
if not removed:
    sys.exit(1)
PY

fail() {
	echo "storage libraries: $*" >&2
	exit 1
}

reset_table() {
	: > "$work/mounts"
	: > "$work/mount.log"
	: > "$work/umount.log"
	rm -rf "$media"
	mkdir -p "$media"
	rm -f "$work/libraries"
}

# A mount-table space must become the real directory, once.
reset_table
mkdir -p "$media/USB Games"
python3 - "$work/mounts" "$media/USB Games" << 'PY'
import sys
path, dest = sys.argv[1], sys.argv[2]
out = []
for ch in dest:
    o = ord(ch)
    if ch in " \t\n\\" or o < 32:
        out.append("\\%03o" % o)
    else:
        out.append(ch)
open(path, "w", encoding="utf-8").write(
    "/dev/sdb1 %s ext4 rw 0 0\n" % "".join(out)
)
PY
got=$("$bin" libraries)
printf '%s\n' "$got" | grep -Fxc -- "$media/USB Games" | grep -qx 1 \
	|| fail "escaped space was not listed once"
printf '%s\n' "$got" | grep -Fqx /storage || fail "primary library missing"

child_of_media() {
	dest=$1
	case "$dest" in
		"$media"/*) ;;
		*) fail "mountpoint left media: $dest" ;;
	esac
	rest=${dest#"$media"/}
	case "$rest" in
		*/*) fail "mountpoint is not one child: $dest" ;;
	esac
	if [ "$(dirname "$dest")" != "$media" ]; then
		fail "mountpoint parent is not media: $dest"
	fi
}

last_move() {
	awk -F '\t' '$1 == "move" { dest = $2 } END { print dest }' "$work/mount.log"
}

add_label() {
	name=$1
	label=$2
	ID_FS_LABEL=$label ID_FS_TYPE=ext4 "$bin" add "$name"
}

reset_table
add_label sda1 "USB Games" || fail "USB Games add failed"
games=$(last_move)
[ "$games" = "$media/USB Games" ] || fail "USB Games mounted at $games"
child_of_media "$games"
grep -q '\\040' "$work/mounts" || fail "space was not escaped in the mount table"
"$bin" libraries | grep -Fxc -- "$games" | grep -qx 1 \
	|| fail "USB Games library was not listed once"

reset_table
add_label sda1 "My Stick (2.0)" || fail "punctuation add failed"
punct=$(last_move)
[ "$punct" = "$media/My Stick (2.0)" ] || fail "punctuation changed: $punct"

reset_table
add_label sda1 "foo/../../etc" || fail "traversal add failed"
trav=$(last_move)
child_of_media "$trav"
case "$trav" in
	*"/"*) ;;
	*) fail "traversal mount missing media prefix" ;;
esac
rest=${trav#"$media"/}
case "$rest" in
	*/*|..|.) fail "traversal escaped: $trav" ;;
esac

reset_table
add_label sda1 "$(printf 'USB\nGames\001')" || fail "control add failed"
ctrl=$(last_move)
child_of_media "$ctrl"
python3 -c 'import sys
s = sys.argv[1]
if any(ord(ch) < 32 or ord(ch) == 127 for ch in s):
    sys.exit(1)
' "$ctrl" || fail "control character survived: $ctrl"
[ "$ctrl" = "$media/USB-Games-" ] || fail "control label became $ctrl"

reset_table
env -u ID_FS_LABEL ID_FS_TYPE=ext4 "$bin" add sda1 || fail "unlabeled add failed"
plain=$(last_move)
[ "$plain" = "$media/sda1" ] || fail "unlabeled disk mounted at $plain"

reset_table
add_label sda1 'A\B' || fail "backslash add failed"
slashy=$(last_move)
[ "$slashy" = "$media/A\B" ] || fail "backslash label became $slashy"
grep -q '\\134' "$work/mounts" || fail "backslash was not escaped as \\134"
"$bin" libraries | grep -Fxc -- "$slashy" | grep -qx 1 \
	|| fail "backslash library was not listed once"

reset_table
add_label sda1 "USB Games" || fail "first collision add failed"
first=$(last_move)
add_label sdb1 "USB Games" || fail "second collision add failed"
second=$(last_move)
[ "$first" = "$media/USB Games" ] || fail "first collision path $first"
[ "$second" = "$media/USB Games-sdb1" ] || fail "second collision path $second"
[ "$first" != "$second" ] || fail "collision stacked one path"
libs=$("$bin" libraries)
printf '%s\n' "$libs" | grep -Fxc -- "$first" | grep -qx 1 || fail "first not once"
printf '%s\n' "$libs" | grep -Fxc -- "$second" | grep -qx 1 || fail "second not once"

: > "$work/umount.log"
"$bin" remove sda1 || fail "remove failed"
remove_target=$(tail -n 1 "$work/umount.log")
[ "$remove_target" = "$first" ] || fail "remove unmounted $remove_target"
if "$bin" libraries | grep -Fqx -- "$first"; then
	fail "removed library stayed"
fi
"$bin" libraries | grep -Fqx -- "$second" || fail "other library was removed"

: > "$work/umount.log"
"$bin" eject || fail "eject failed"
grep -Fqx -- "$second" "$work/umount.log" || fail "eject missed $second"
if "$bin" libraries | grep -Fqx -- "$second"; then
	fail "ejected library stayed"
fi

echo "storage libraries ok"
