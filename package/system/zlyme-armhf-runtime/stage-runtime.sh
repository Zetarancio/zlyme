#!/bin/sh
# Stage the ARMHF runtime into an approved root.
# The source is checked in a private tree. Nothing in the destination
# changes until that check finishes. Publishing the library directory
# and the loader is two renames, not one filesystem transaction. If
# either rename or the final check fails, both ARMHF-owned paths are
# put back. AArch64 libc and its interpreter are never replaced.
# shellcheck disable=SC1007
set -eu

die() { echo "armhf-stage: $*" >&2; exit 1; }

sysroot=${ZLYME_ARMHF_SYSROOT:?set ZLYME_ARMHF_SYSROOT to the armhf target tree}
dest=${1:?destination root}
commit=0
finishing=0
published_lib=0
published_loader=0
old_lib=
old_loader=
stage=

elf_byte() {
	# shellcheck disable=SC2046
	set -- $(od -An -t x1 -j "$1" -N 1 "$2")
	printf '%s' "$1"
}

elf_machine() {
	# shellcheck disable=SC2046
	set -- $(od -An -t x1 -j 18 -N 2 "$1")
	printf '%s%s' "$1" "$2"
}

require_armhf_elf() {
	file=$1
	[ "$(elf_byte 4 "$file")" = "01" ] || die "$file is not ELF32"
	[ "$(elf_byte 5 "$file")" = "01" ] || die "$file is not little-endian"
	[ "$(elf_machine "$file")" = "2800" ] || die "$file is not ARM"
	readelf -h "$file" | grep -q 'hard-float ABI' || die "$file is not hard-float"
	readelf -A "$file" | grep -q 'Tag_ABI_VFP_args: VFP registers' \
		|| die "$file does not use VFP register arguments"
}

interp_of() {
	readelf -l "$1" 2>/dev/null | awk '
		/Requesting program interpreter/ {
			gsub(/[][]/, "", $NF)
			print $NF
		}
	'
}

require_interp() {
	file=$1
	got=$(interp_of "$file")
	[ -n "$got" ] || die "$file has no interpreter"
	[ "$got" = "/lib/ld-linux-armhf.so.3" ] || die "$file interpreter is $got"
}

check_needed() {
	file=$1
	root=$2
	needed_list=$(readelf -d "$file" | awk '/NEEDED/ { gsub(/[][]/, "", $NF); print $NF }')
	for needed in $needed_list; do
		if [ "$needed" = "ld-linux-armhf.so.3" ]; then
			[ -f "$root/lib/ld-linux-armhf.so.3" ] || die "$file needs the loader"
			continue
		fi
		[ -e "$root/usr/lib/zlyme-armhf/$needed" ] \
			|| die "$file needs $needed, which is not in the private directory"
	done
}

# Follow a relative symlink chain. The final file must be an ARMHF ELF.
resolve_link() {
	cur=$1
	hops=0
	while [ -L "$cur" ]; do
		hops=$((hops + 1))
		[ "$hops" -le 8 ] || die "symlink chain is too long: $1"
		target=$(readlink "$cur")
		case "$target" in
			/* | *..* | */*) die "symlink escapes the private directory: $cur -> $target" ;;
		esac
		cur=$(dirname "$cur")/$target
	done
	[ -f "$cur" ] || die "dangling symlink: $1"
	require_armhf_elf "$cur"
}

rollback() {
	rc=0
	if [ "$published_loader" = 1 ]; then
		rm -f "$dest/lib/ld-linux-armhf.so.3" || rc=1
		published_loader=0
	fi
	if [ -n "$old_loader" ] && [ -e "$old_loader" ]; then
		mv "$old_loader" "$dest/lib/ld-linux-armhf.so.3" || rc=1
		old_loader=
	fi
	if [ "$published_lib" = 1 ]; then
		rm -rf "$dest/usr/lib/zlyme-armhf" || rc=1
		published_lib=0
	fi
	if [ -n "$old_lib" ] && [ -d "$old_lib" ]; then
		mv "$old_lib" "$dest/usr/lib/zlyme-armhf" || rc=1
		old_lib=
	fi
	return "$rc"
}

finish() {
	status=${1:-$?}
	[ "$finishing" = 1 ] && exit "$status"
	finishing=1
	trap - EXIT INT TERM HUP
	if [ "$commit" = 1 ]; then
		rm -rf "$stage"
		[ -n "$old_lib" ] && rm -rf "$old_lib"
		[ -n "$old_loader" ] && rm -f "$old_loader"
		exit "$status"
	fi
	if ! rollback; then
		echo "armhf-stage: rollback failed" >&2
		rm -rf "$stage"
		exit 1
	fi
	rm -rf "$stage"
	exit "$status"
}
trap 'finish $?' EXIT
trap 'echo "armhf-stage: interrupted" >&2; finish 130' INT TERM HUP

case "$dest" in
	/ | /storage | /storage/* | /usr | /lib | /usr/lib) die "refusing destination $dest" ;;
esac
[ -d "$dest" ] || die "destination is not a directory: $dest"
[ -L "$dest" ] && die "destination is a symlink"
real_dest=$(CDPATH= cd -P -- "$dest" && pwd) || die "cannot resolve $dest"
allow=${ZLYME_ARMHF_DEST_ROOT:-}
if [ -z "$allow" ]; then
	repo=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
	allow="$repo/output:$repo/output-armhf:/zlyme/output"
fi
ok_dest=0
old_ifs=$IFS
IFS=:
for one in $allow; do
	[ -n "$one" ] || continue
	[ -d "$one" ] || continue
	real_one=$(CDPATH= cd -P -- "$one" && pwd) || continue
	case "$real_dest" in
		"$real_one" | "$real_one"/*) ok_dest=1 ;;
	esac
done
IFS=$old_ifs
[ "$ok_dest" = 1 ] || die "destination is outside the approved tree: $real_dest"
for part in lib usr usr/lib; do
	if [ -L "$dest/$part" ]; then
		die "destination component is a symlink: $part"
	fi
done
if [ -L "$dest/lib/ld-linux-armhf.so.3" ] || [ -L "$dest/usr/lib/zlyme-armhf" ]; then
	die "refusing to publish through a symlink"
fi

loader=$sysroot/lib/ld-linux-armhf.so.3
libdir=$sysroot/usr/lib/zlyme-armhf
[ -f "$loader" ] || die "loader missing: $loader"
[ -d "$libdir" ] || die "private library directory missing: $libdir"
command -v readelf >/dev/null 2>&1 || die "readelf is required"
command -v strings >/dev/null 2>&1 || die "strings is required"
out_dir=$(CDPATH= cd -- "$sysroot/.." && pwd)
[ -f "$out_dir/.zlyme-defconfig" ] || die "sysroot is not the ARMHF defconfig"
[ -f "$out_dir/.config" ] || die "sysroot has no Buildroot config"
stamp=$(tr -d '[:space:]' < "$out_dir/.zlyme-defconfig")
[ "$stamp" = "zlyme_my355_armhf_defconfig" ] || die "sysroot is not the ARMHF defconfig"
grep -qx 'BR2_arm=y' "$out_dir/.config" || die "sysroot is not BR2_arm"
grep -qx 'BR2_ARM_EABIHF=y' "$out_dir/.config" || die "sysroot is not hard-float"
if grep -qx 'BR2_aarch64=y' "$out_dir/.config"; then
	die "sysroot is AArch64"
fi
if ! strings "$loader" | grep -qx '/usr/lib/zlyme-armhf/'; then
	die "loader does not search /usr/lib/zlyme-armhf"
fi
if strings "$loader" | grep -qx '/lib/' || strings "$loader" | grep -qx '/usr/lib/'; then
	die "loader still searches an AArch64 library directory"
fi

stage=$(mktemp -d "$dest/.armhf-stage.XXXXXX")
mkdir -p "$stage/lib" "$stage/usr/lib/zlyme-armhf"
cp -a "$loader" "$stage/lib/ld-linux-armhf.so.3"
require_armhf_elf "$stage/lib/ld-linux-armhf.so.3"

cp -a "$libdir/." "$stage/usr/lib/zlyme-armhf/"
if find "$stage/usr/lib/zlyme-armhf" -mindepth 1 \
	! -type d ! -type f ! -type l | grep -q .; then
	die "private runtime contains a special file"
fi
file_list=$stage/.armhf-files
find "$stage/usr/lib/zlyme-armhf" -mindepth 1 \
	\( -type f -o -type l \) -print | sort > "$file_list"
while IFS= read -r src; do
	[ -n "$src" ] || continue
	if [ -L "$src" ]; then
		resolve_link "$src"
		continue
	fi
	case $(elf_byte 4 "$src") in
		01)
			require_armhf_elf "$src"
			soname=$(readelf -d "$src" | awk '/SONAME/ { gsub(/[][]/, "", $NF); print $NF; exit }')
			base=$(basename "$src")
			if [ -n "$soname" ] && [ "$soname" != "$base" ]; then
				link=$(dirname "$src")/$soname
				if [ ! -L "$link" ] || [ "$(readlink "$link")" != "$base" ]; then
					die "$base SONAME $soname has no matching symlink"
				fi
			fi
			search=$(readelf -d "$src" | awk '/\(RPATH\)|\(RUNPATH\)/ {
				sub(/.*\[/, ""); sub(/\].*/, ""); printf "%s", $0
			}')
			[ -z "$search" ] || die "$(basename "$src") has an RPATH or RUNPATH: $search"
			got_interp=$(interp_of "$src")
			if [ -n "$got_interp" ] && [ "$got_interp" != "/lib/ld-linux-armhf.so.3" ]; then
				die "$(basename "$src") interpreter is $got_interp"
			fi
			check_needed "$src" "$stage"
			;;
		02) die "ELF64 in the ARMHF runtime: $(basename "$src")" ;;
		*)
			if grep -q '/lib/\|/usr/lib/' "$src"; then
				die "text file names an AArch64 library path: $(basename "$src")"
			fi
			;;
	esac
done < "$file_list"
require_interp "$stage/usr/lib/zlyme-armhf/libc.so.6"
[ -f "$stage/usr/lib/zlyme-armhf/libgcc_s.so.1" ] || die "libgcc_s.so.1 is missing"
check_needed "$stage/lib/ld-linux-armhf.so.3" "$stage"

pause_at() {
	echo "armhf-stage: pausing $1" >&2
	left=${ZLYME_ARMHF_PAUSE_SEC:-30}
	while [ "$left" -gt 0 ]; do
		sleep 1
		left=$((left - 1))
	done
}

if [ "${ZLYME_ARMHF_PAUSE_AT:-}" = "before-publish" ]; then
	pause_at before-publish
fi

mkdir -p "$dest/lib" "$dest/usr/lib"
if [ -d "$dest/usr/lib/zlyme-armhf" ]; then
	old_lib=$dest/usr/lib/.zlyme-armhf-old.$$
	mv "$dest/usr/lib/zlyme-armhf" "$old_lib"
fi
if [ "${ZLYME_ARMHF_FAIL_AT:-}" = "publish-lib" ]; then
	die "injected library publication failure"
fi
mv "$stage/usr/lib/zlyme-armhf" "$dest/usr/lib/zlyme-armhf"
published_lib=1

if [ "${ZLYME_ARMHF_PAUSE_AT:-}" = "after-lib" ]; then
	pause_at after-lib
fi

if [ -e "$dest/lib/ld-linux-armhf.so.3" ]; then
	old_loader=$dest/lib/.ld-linux-armhf.so.3.old.$$
	mv "$dest/lib/ld-linux-armhf.so.3" "$old_loader"
fi
if [ "${ZLYME_ARMHF_FAIL_AT:-}" = "publish-loader" ]; then
	die "injected loader publication failure"
fi
mv "$stage/lib/ld-linux-armhf.so.3" "$dest/lib/ld-linux-armhf.so.3"
published_loader=1

require_armhf_elf "$dest/lib/ld-linux-armhf.so.3"
require_armhf_elf "$dest/usr/lib/zlyme-armhf/libc.so.6"
require_interp "$dest/usr/lib/zlyme-armhf/libc.so.6"
require_armhf_elf "$dest/usr/lib/zlyme-armhf/libgcc_s.so.1"
if [ -e "$dest/lib/libc.so.6" ]; then
	[ "$(elf_byte 4 "$dest/lib/libc.so.6")" != "01" ] || die "ARMHF libc landed in /lib"
fi
if [ "${ZLYME_ARMHF_FAIL_AT:-}" = "final" ]; then
	die "injected final validation failure"
fi
commit=1
echo "armhf runtime staged"
