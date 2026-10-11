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
: > "$work/python.log"

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
export ZLYME_PYTHON_LOG="$work/python.log"

# Production storage uses this PATH. A real interpreter must not be reached.
cat > "$work/bin/python3" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_PYTHON_LOG:?}"
exit 127
EOF

cat > "$work/bin/mount" << 'EOF'
#!/bin/sh
set -eu
# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
move=0
n=0
src=
dest=
for arg in "$@"; do
	if [ "$arg" = "--move" ]; then
		move=1
		continue
	fi
	case "$arg" in
		-*) continue ;;
	esac
	src=$dest
	dest=$arg
	n=$((n + 1))
done
[ "$n" -ge 2 ] || exit 1
if [ "$move" -eq 1 ]; then
	printf 'move\t%s\n' "$dest" >> "$ZLYME_FAKE_MOUNT_LOG"
else
	printf 'mount\t%s\n' "$dest" >> "$ZLYME_FAKE_MOUNT_LOG"
fi
encode() {
	printf '%s' "$1" | awk '
		BEGIN { ORS = "" }
		{
			for (i = 1; i <= length($0); i++) {
				c = substr($0, i, 1)
				if (c == " ") printf "\\040"
				else if (c == "\t") printf "\\011"
				else if (c == "\\") printf "\\134"
				else if (c == "\n") printf "\\012"
				else printf "%s", c
			}
		}
	'
}
enc_src=$(encode "$src")
enc_dest=$(encode "$dest")
tmp=$(mktemp)
if [ "$move" -eq 1 ]; then
	replaced=0
	while IFS= read -r line || [ -n "$line" ]; do
		[ -n "$line" ] || continue
		field=$(printf '%s\n' "$line" | awk 'NF >= 2 { print $2; exit }')
		raw_src=$(printf '%s\n' "$line" | awk 'NF >= 2 { print $1; exit }')
		if [ "$replaced" -eq 0 ] && [ -n "$field" ] \
			&& [ "$(mounts_decode "$field")" = "$src" ]; then
			printf '%s %s fake rw 0 0\n' "$raw_src" "$enc_dest"
			replaced=1
		else
			printf '%s\n' "$line"
		fi
	done < "$ZLYME_STORAGE_MOUNTS" > "$tmp"
	if [ "$replaced" -eq 0 ]; then
		printf '%s %s fake rw 0 0\n' "$enc_src" "$enc_dest" >> "$tmp"
	fi
else
	if [ -s "$ZLYME_STORAGE_MOUNTS" ]; then
		cat "$ZLYME_STORAGE_MOUNTS" > "$tmp"
	else
		: > "$tmp"
	fi
	printf '%s %s fake rw 0 0\n' "$enc_src" "$enc_dest" >> "$tmp"
fi
mv -f "$tmp" "$ZLYME_STORAGE_MOUNTS"
EOF

cat > "$work/bin/umount" << 'EOF'
#!/bin/sh
set -eu
# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
target=
for arg in "$@"; do
	case "$arg" in
		-*) continue ;;
	esac
	target=$arg
done
[ -n "$target" ] || exit 1
printf '%s\n' "$target" >> "$ZLYME_FAKE_UMOUNT_LOG"
if [ "${ZLYME_FAKE_UMOUNT_FAIL:-0}" = 1 ]; then
	exit 1
fi
tmp=$(mktemp)
removed=0
while IFS= read -r line || [ -n "$line" ]; do
	[ -n "$line" ] || continue
	field=$(printf '%s\n' "$line" | awk 'NF >= 2 { print $2; exit }')
	if [ "$removed" -eq 0 ] && [ -n "$field" ] \
		&& [ "$(mounts_decode "$field")" = "$target" ]; then
		removed=1
		continue
	fi
	printf '%s\n' "$line"
done < "$ZLYME_STORAGE_MOUNTS" > "$tmp"
mv -f "$tmp" "$ZLYME_STORAGE_MOUNTS"
[ "$removed" -eq 1 ]
EOF
chmod 0755 "$work/bin/python3" "$work/bin/mount" "$work/bin/umount"

fail() {
	echo "storage libraries: $*" >&2
	exit 1
}

if grep -q '^BR2_PACKAGE_PYTHON3=y' "$ROOT/configs/zlyme_my355_minimal_defconfig"; then
	fail "minimal defconfig selects Python 3"
fi
if grep -n python3 "$bin" "$ZLYME_MOUNTS_LIB"; then
	fail "storage helper names python3"
fi

# shellcheck disable=SC1090
. "$ZLYME_MOUNTS_LIB"
[ "$(mounts_decode 'USB\040Games')" = "USB Games" ] || fail "space escape"
[ "$(mounts_decode 'A\011B')" = "$(printf 'A\tB')" ] || fail "tab escape"
[ "$(mounts_decode 'A\012B')" = "$(printf 'A\nB')" ] || fail "newline escape"
[ "$(mounts_decode 'A\134B')" = 'A\B' ] || fail "backslash escape"

reset_table() {
	: > "$work/mounts"
	: > "$work/mount.log"
	: > "$work/umount.log"
	rm -rf "$media"
	mkdir -p "$media"
	rm -f "$work/libraries"
}

encode_field() {
	printf '%s' "$1" | awk '
		BEGIN { ORS = "" }
		{
			for (i = 1; i <= length($0); i++) {
				c = substr($0, i, 1)
				if (c == " ") printf "\\040"
				else if (c == "\t") printf "\\011"
				else if (c == "\\") printf "\\134"
				else if (c == "\n") printf "\\012"
				else printf "%s", c
			}
		}
	'
}

# A mount-table space must become the real directory, once.
reset_table
mkdir -p "$media/USB Games"
printf '/dev/sdb1 %s ext4 rw 0 0\n' "$(encode_field "$media/USB Games")" \
	> "$work/mounts"
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
printf '%s' "$ctrl" | awk '
	BEGIN {
		RS = "\0"
		bad = 0
		for (i = 0; i < 32; i++) ctrl[sprintf("%c", i)] = 1
		ctrl[sprintf("%c", 127)] = 1
	}
	{
		for (i = 1; i <= length($0); i++) {
			c = substr($0, i, 1)
			if (c in ctrl) bad = 1
		}
	}
	END { exit bad ? 1 : 0 }
' || fail "control character survived: $ctrl"
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

if [ -s "$ZLYME_PYTHON_LOG" ]; then
	fail "storage helper invoked python3"
fi

echo "storage libraries ok"
