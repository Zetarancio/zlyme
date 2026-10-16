#!/bin/sh
# Install the ARMHF runtime into a root without touching AArch64 libraries.
# Every file is checked in a private tree first. A rejected file leaves
# the destination unchanged. This does not enable DEVICE_HAS_ARMHF.
# shellcheck disable=SC1007
set -eu

fail() { echo "armhf-stage: $*" >&2; exit 1; }

sysroot=${ZLYME_ARMHF_SYSROOT:?set ZLYME_ARMHF_SYSROOT to the armhf target tree}
dest=${1:?destination root}
case "$dest" in
	/ | /storage | /storage/* | /usr | /lib | /usr/lib)
		fail "refusing destination $dest"
		;;
esac
[ -d "$dest" ] || fail "destination is not a directory: $dest"

loader=$sysroot/lib/ld-linux-armhf.so.3
libdir=$sysroot/usr/lib/zlyme-armhf
[ -f "$loader" ] || fail "loader missing: $loader"
[ -d "$libdir" ] || fail "private library directory missing: $libdir"
command -v readelf >/dev/null 2>&1 || fail "readelf is required to check dependencies"
command -v strings >/dev/null 2>&1 || fail "strings is required to check the loader"

if ! strings "$loader" | grep -qx '/usr/lib/zlyme-armhf/'; then
	fail "loader does not search /usr/lib/zlyme-armhf"
fi
if strings "$loader" | grep -qx '/lib/' || strings "$loader" | grep -qx '/usr/lib/'; then
	fail "loader still searches an AArch64 library directory"
fi

elf_machine() {
	# shellcheck disable=SC2046
	set -- $(od -An -t x1 -j 18 -N 2 "$1")
	printf '%s%s' "$1" "$2"
}

elf_class() {
	# shellcheck disable=SC2046
	set -- $(od -An -t x1 -j 4 -N 1 "$1")
	printf '%s' "$1"
}

require_armhf_elf() {
	file=$1
	class=$(elf_class "$file")
	machine=$(elf_machine "$file")
	[ "$class" = "01" ] || fail "$file is not ELF32"
	[ "$machine" = "2800" ] || fail "$file is not ARM (machine $machine)"
}

# $1 ELF. Every NEEDED name must be the ARMHF loader or a SONAME in
# the private directory being staged.
check_needed() {
	file=$1
	root=$2
	needed_list=$(readelf -d "$file" | awk '/NEEDED/ { gsub(/[][]/, "", $NF); print $NF }')
	for needed in $needed_list; do
		if [ "$needed" = "ld-linux-armhf.so.3" ]; then
			[ -f "$root/lib/ld-linux-armhf.so.3" ] || fail "$file needs the loader"
			continue
		fi
		if ! [ -e "$root/usr/lib/zlyme-armhf/$needed" ]; then
			fail "$file needs $needed, which is not in the private directory"
		fi
	done
}

stage=$(mktemp -d "$dest/.armhf-stage.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT

mkdir -p "$stage/lib" "$stage/usr/lib/zlyme-armhf"
cp -a "$loader" "$stage/lib/ld-linux-armhf.so.3"
require_armhf_elf "$stage/lib/ld-linux-armhf.so.3"

for src in "$libdir"/*; do
	[ -e "$src" ] || [ -L "$src" ] || continue
	name=$(basename "$src")
	dst=$stage/usr/lib/zlyme-armhf/$name
	if [ -L "$src" ]; then
		target=$(readlink "$src")
		case "$target" in
			/* | *..* | */*) fail "symlink escapes the private directory: $src -> $target" ;;
		esac
		ln -s "$target" "$dst"
	else
		cp -a "$src" "$dst"
	fi
done

for src in "$stage/usr/lib/zlyme-armhf"/*; do
	[ -e "$src" ] || [ -L "$src" ] || continue
	if [ -L "$src" ]; then
		target=$(readlink "$src")
		[ -f "$stage/usr/lib/zlyme-armhf/$target" ] || fail "dangling symlink $(basename "$src")"
		continue
	fi
	case $(elf_class "$src") in
		01)
			require_armhf_elf "$src"
			check_needed "$src" "$stage"
			;;
		02) fail "ELF64 in the ARMHF runtime: $(basename "$src")" ;;
		*)
			if grep -q '/lib/\|/usr/lib/' "$src"; then
				fail "text file names an AArch64 library path: $(basename "$src")"
			fi
			;;
	esac
done
check_needed "$stage/lib/ld-linux-armhf.so.3" "$stage"

# The private tree is complete. Swap it in, and put the previous
# private directory back if that swap fails.
mkdir -p "$dest/lib" "$dest/usr/lib"
old_lib=
if [ -d "$dest/usr/lib/zlyme-armhf" ]; then
	old_lib=$dest/usr/lib/.zlyme-armhf-old.$$
	mv "$dest/usr/lib/zlyme-armhf" "$old_lib"
fi
if ! mv "$stage/usr/lib/zlyme-armhf" "$dest/usr/lib/zlyme-armhf"; then
	if [ -n "$old_lib" ]; then
		mv "$old_lib" "$dest/usr/lib/zlyme-armhf"
	fi
	fail "could not publish the private library directory"
fi

old_loader=
if [ -e "$dest/lib/ld-linux-armhf.so.3" ]; then
	old_loader=$dest/lib/.ld-linux-armhf.so.3.old.$$
	mv "$dest/lib/ld-linux-armhf.so.3" "$old_loader"
fi
if ! mv "$stage/lib/ld-linux-armhf.so.3" "$dest/lib/ld-linux-armhf.so.3"; then
	if [ -n "$old_loader" ]; then
		mv "$old_loader" "$dest/lib/ld-linux-armhf.so.3"
	fi
	if [ -n "$old_lib" ] && [ -d "$dest/usr/lib/zlyme-armhf" ]; then
		rm -rf "$dest/usr/lib/zlyme-armhf"
		mv "$old_lib" "$dest/usr/lib/zlyme-armhf"
	fi
	fail "could not publish the ARMHF loader"
fi
[ -n "$old_lib" ] && rm -rf "$old_lib"
[ -n "$old_loader" ] && rm -f "$old_loader"
chmod 755 "$dest/lib/ld-linux-armhf.so.3" || true

if [ -e "$dest/lib/libc.so.6" ]; then
	class=$(elf_class "$dest/lib/libc.so.6")
	[ "$class" != "01" ] || fail "ARMHF libc landed in /lib"
fi
require_armhf_elf "$dest/lib/ld-linux-armhf.so.3"
require_armhf_elf "$dest/usr/lib/zlyme-armhf/libc.so.6"
require_armhf_elf "$dest/usr/lib/zlyme-armhf/libgcc_s.so.1"

echo "armhf runtime staged"
