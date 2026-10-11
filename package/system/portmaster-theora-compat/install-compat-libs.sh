#!/bin/sh
# Install the libtheora 1.1.1 decoder into $1/usr/lib/compat.
# $2 is the package DESTDIR from `make install`.
#
# This package owns libtheoradec.so.1 and libtheoradec.so.1.* only.
# Other files in that directory belong to whoever installed them.
set -eu

target=${1:?}
staged=${2:?}
dest=$target/usr/lib/compat
src=$staged/usr/lib/compat

mkdir -p "$dest"

# A name that does not match is left untouched, including when the glob
# matches nothing and the shell leaves the pattern literal.
for old in "$dest"/libtheoradec.so.1 "$dest"/libtheoradec.so.1.*; do
	if [ -e "$old" ] || [ -L "$old" ]; then
		rm -f "$old"
	fi
done

real=$(find "$src" -name 'libtheoradec.so.1.*' -type f)
test -n "$real"
test -L "$src/libtheoradec.so.1"
base=$(basename "$real")
cp -f "$real" "$dest/$base"
chmod 0644 "$dest/$base"
ln -s "$base" "$dest/libtheoradec.so.1"
