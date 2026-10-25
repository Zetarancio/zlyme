#!/bin/sh
# Install libxml2 2.13.9 into $1/usr/lib/compat.
# $2 is the package DESTDIR from `make install`.
#
# This package owns libxml2.so.2 and libxml2.so.2.* only.
# It does not install the unversioned libxml2.so link, headers, or
# anything under /usr/lib.
set -eu

target=${1:?}
staged=${2:?}
dest=$target/usr/lib/compat

mkdir -p "$dest"

for old in "$dest"/libxml2.so.2 "$dest"/libxml2.so.2.*; do
	if [ -e "$old" ] || [ -L "$old" ]; then
		rm -f "$old"
	fi
done

real=$(find "$staged" -name 'libxml2.so.2.*' -type f)
test -n "$real"
test "$(printf '%s\n' "$real" | grep -c .)" -eq 1
base=$(basename "$real")
case "$base" in
libxml2.so.2.*) ;;
*)
	echo "portmaster-xml2-compat: refusing $base" >&2
	exit 1
	;;
esac
cp -f "$real" "$dest/$base"
chmod 0644 "$dest/$base"
ln -s "$base" "$dest/libxml2.so.2"
test ! -e "$dest/libxml2.so"
test ! -e "$target/usr/lib/libxml2.so.2"
