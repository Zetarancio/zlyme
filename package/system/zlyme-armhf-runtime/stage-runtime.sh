#!/bin/sh
# Install the ARMHF runtime into a root without touching AArch64 libraries.
# The sysroot comes from the armhf Buildroot defconfig. This does not
# enable DEVICE_HAS_ARMHF and it does not search /lib or /usr/lib.
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

loader=$sysroot/lib/ld-linux-armhf.so.3
libdir=$sysroot/usr/lib/zlyme-armhf
[ -f "$loader" ] || fail "loader missing: $loader"
[ -d "$libdir" ] || fail "private library directory missing: $libdir"

if ! strings "$loader" | grep -qx '/usr/lib/zlyme-armhf/'; then
	fail "loader does not search /usr/lib/zlyme-armhf"
fi
if strings "$loader" | grep -qx '/lib/' || strings "$loader" | grep -qx '/usr/lib/'; then
	fail "loader still searches an AArch64 library directory"
fi

# 32-bit ARM is ELF class 01 and e_machine 0x28, little endian.
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

require_armhf_elf "$loader"

# A file already at the destination must stay byte-for-byte if we do not
# own that path. Record the AArch64 libc and loader before copying.
stamp() {
	path=$1
	if [ -e "$path" ]; then
		sha256sum "$path"
	else
		printf 'absent %s\n' "$path"
	fi
}
before_libc=$(stamp "$dest/lib/libc.so.6")
before_a64=$(stamp "$dest/lib/ld-linux-aarch64.so.1")

install_new() {
	src=$1
	dst=$2
	if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
		fail "refusing to replace $dst"
	fi
	mkdir -p "$(dirname "$dst")"
	if [ -L "$src" ]; then
		target=$(readlink "$src")
		case "$target" in
			/* | *..*) fail "symlink escapes the private directory: $src -> $target" ;;
		esac
		ln -sfn "$target" "$dst"
	else
		cp -a "$src" "$dst"
	fi
}

install_new "$loader" "$dest/lib/ld-linux-armhf.so.3"
require_armhf_elf "$dest/lib/ld-linux-armhf.so.3"

for src in "$libdir"/*; do
	[ -e "$src" ] || [ -L "$src" ] || continue
	name=$(basename "$src")
	dst=$dest/usr/lib/zlyme-armhf/$name
	install_new "$src" "$dst"
	if [ -L "$dst" ]; then
		continue
	fi
	case $(elf_class "$dst") in
		01) require_armhf_elf "$dst" ;;
		02) fail "ELF64 in the ARMHF runtime: $name" ;;
		*)
			# A linker script may name a library in this directory.
			# It may not point at /lib or /usr/lib.
			if grep -q '/lib/\|/usr/lib/' "$dst"; then
				fail "text file names an AArch64 library path: $name"
			fi
			;;
	esac
done

after_libc=$(stamp "$dest/lib/libc.so.6")
after_a64=$(stamp "$dest/lib/ld-linux-aarch64.so.1")
[ "$before_libc" = "$after_libc" ] || fail "AArch64 libc changed"
[ "$before_a64" = "$after_a64" ] || fail "AArch64 loader changed"

if [ -e "$dest/lib/libc.so.6" ]; then
	class=$(elf_class "$dest/lib/libc.so.6")
	[ "$class" != "01" ] || fail "ARMHF libc landed in /lib"
fi
if [ ! -f "$dest/usr/lib/zlyme-armhf/libc.so.6" ]; then
	fail "private libc was not installed"
fi
require_armhf_elf "$dest/usr/lib/zlyme-armhf/libc.so.6"
if [ ! -f "$dest/usr/lib/zlyme-armhf/libgcc_s.so.1" ]; then
	fail "private libgcc was not installed"
fi
require_armhf_elf "$dest/usr/lib/zlyme-armhf/libgcc_s.so.1"

echo "armhf runtime staged"
