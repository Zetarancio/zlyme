#!/bin/sh
# A library rescan must not delete a BIOS view that a launch is publishing.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
libsh=$ROOT/package/system/nextui/zlyme/zlyme-library.sh
storage=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage
if grep -q 'rm -rf /run/zlyme/bios-cache' "$storage"; then
	echo "storage still deletes the BIOS cache" >&2
	exit 1
fi
grep -q 'bios-generation' "$storage"
grep -q 'bios-generation' "$libsh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/run" "$work/card/Bios" "$work/py"
printf '%s\n' "$work/card" > "$work/libs"
cat > "$work/py/slow.py" << 'EOF'
#!/usr/bin/env python3
import os, sys, time
stage = sys.argv[1]
os.makedirs(stage, exist_ok=True)
open(os.path.join(stage, "building"), "w").write("1")
time.sleep(1)
open(os.path.join(stage, ".zlyme-ready"), "w").write("ok")
EOF
chmod +x "$work/py/slow.py"

# shellcheck disable=SC1090
. "$libsh"
export ZLYME_RUN_DIR=$work/run
export ZLYME_LIBRARIES_FILE=$work/libs
export ZLYME_BIOS_PY=$work/py/slow.py

zlyme_bios_view "$work/card" &
pid=$!
sleep 0.2
# What a rescan does: bump the generation and drop only the symlink.
n=0
if [ -r "$work/run/bios-generation" ]; then
	n=$(tr -cd '0-9' < "$work/run/bios-generation")
fi
printf '%s\n' "$((n + 1))" > "$work/run/bios-generation"
rm -f "$work/run/bios"
wait "$pid"
# The in-flight view finished. Its staging directory was not removed.
ready=$(find "$work/run/bios-cache" -name .zlyme-ready | head -n 1)
test -n "$ready"
test -f "$(dirname "$ready")/building"

# A second resolve sees the new generation and builds another view.
zlyme_bios_view "$work/card"
nready=$(find "$work/run/bios-cache" -name .zlyme-ready | wc -l)
test "$nready" -ge 2
echo "bios race ok"
