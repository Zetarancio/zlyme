#!/bin/sh
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-portmaster-root"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sd2=$work/sd2
usb="$work/usb disk"
bs="$work/A\\B"
mkdir -p "$sd2" "$usb" "$bs" "$work/bin"
export ZLYME_PM_FLAG="$work/flag"
export ZLYME_LIBRARIES_FILE="$work/libraries"
export ZLYME_PM_MOUNTS="$work/mounts"
export ZLYME_MOUNTS_LIB="$ROOT/board/my355/fsoverlay/usr/share/zlyme/mounts.sh"
export ZLYME_PM_RUN="$work/run"
export ZLYME_PYTHON_LOG="$work/python.log"
: > "$ZLYME_PYTHON_LOG"
cat > "$work/bin/python3" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${ZLYME_PYTHON_LOG:?}"
exit 127
EOF
chmod 0755 "$work/bin/python3"
export PATH="$work/bin:$PATH"
encode_mount() {
	printf '%s' "$1" | awk '
		BEGIN { ORS = "" }
		{
			for (i = 1; i <= length($0); i++) {
				c = substr($0, i, 1)
				if (c == " ") printf "\\040"
				else if (c == "\\") printf "\\134"
				else if (c == "\t") printf "\\011"
				else if (c == "\n") printf "\\012"
				else printf "%s", c
			}
		}
	'
}
write_mounts() {
	: > "$work/mounts"
	for path in "$@"; do
		printf '/dev/fake %s fake rw 0 0\n' "$(encode_mount "$path")" >> "$work/mounts"
	done
}
printf '%s\n' /storage "$sd2" "$usb" "$bs" > "$work/libraries"
write_mounts "$sd2" "$usb" "$bs"
if grep -n python3 "$BIN" "$ZLYME_MOUNTS_LIB"; then
	echo "minimal library path names python3" >&2
	exit 1
fi

"$BIN" set /storage
test ! -s "$work/flag"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "/storage/Roms/.portmaster"
# The GUI is a child process. The assignment must be exported.
sh -c 'test "$HM_TOOLS_DIR" = "/storage/Roms/.portmaster"'
test "$HM_PORTS_DIR" = "/storage/Roms/Ports (PORTS)"
test "$HM_SCRIPTS_DIR" = "$HM_PORTS_DIR"

if "$BIN" set "$work/not-a-library"; then
	echo "unknown root was accepted" >&2
	exit 1
fi

"$BIN" set "$sd2"
test ! -d "$sd2/Roms/.portmaster"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "$sd2/Roms/.portmaster"
test "$HM_PORTS_DIR" = "$sd2/Roms/Ports (PORTS)"
test "$HM_SCRIPTS_DIR" = "$HM_PORTS_DIR"
test "$("$BIN" get)" = "$sd2"

"$BIN" set "$usb"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "$usb/Roms/.portmaster"
test "$HM_PORTS_DIR" = "$usb/Roms/Ports (PORTS)"
test "$("$BIN" get)" = "$usb"

"$BIN" set "$bs"
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "$bs/Roms/.portmaster"
test "$("$BIN" get)" = "$bs"

if "$BIN" link-libs; then
	echo "link-libs is still a root command" >&2
	exit 1
fi
test ! -d "$sd2/Roms/.portmaster"

# The mountpoint stays. Absent means it is not in the registry.
"$BIN" set "$sd2"
printf '%s\n' /storage > "$work/libraries"
test -d "$sd2"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "unregistered sd2 was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
if "$BIN" get >"$work/out" 2>"$work/err"; then
	echo "unregistered sd2 fell back" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"

"$BIN" set "$usb" && echo "set accepted an unregistered usb path" >&2 && exit 1
printf '%s\n' "$usb" > "$work/flag"
test -d "$usb"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "unregistered usb was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
if grep -q '/storage' "$work/out"; then
	echo "missing library fell back to /storage" >&2
	exit 1
fi

mkdir -p "$work/not-registered"
printf '%s\n' "$work/not-registered" > "$work/flag"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "unregistered directory was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"

printf '%s\n%s\n' "$sd2" "$usb" > "$work/flag"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "multi-line selection was concatenated" >&2
	exit 1
fi
grep -q "malformed" "$work/err"
test ! -s "$work/out"
if "$BIN" get >"$work/out" 2>"$work/err"; then
	echo "malformed get succeeded" >&2
	exit 1
fi
test ! -s "$work/out"

# Listed and the directory exists. The disk is not in the mount table.
printf '%s\n' /storage "$sd2" "$usb" > "$work/libraries"
printf '%s\n' "$sd2" > "$work/flag"
write_mounts "$usb"
test -d "$sd2"
if "$BIN" export >"$work/out" 2>"$work/err"; then
	echo "stale library entry was accepted" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
if "$BIN" get >"$work/out" 2>"$work/err"; then
	echo "stale library entry fell back" >&2
	exit 1
fi
grep -q "not inserted" "$work/err"
test ! -s "$work/out"
if grep -q '/storage' "$work/out"; then
	echo "stale library fell back to /storage" >&2
	exit 1
fi
if "$BIN" set "$sd2"; then
	echo "set accepted a stale library entry" >&2
	exit 1
fi

# /storage is the primary. It does not have to appear in the mount table.
write_mounts "$sd2" "$usb"
printf '%s\n' /storage "$sd2" "$usb" > "$work/libraries"
"$BIN" set /storage
test ! -s "$work/flag"
test "$("$BIN" get)" = /storage
eval "$("$BIN" export)"
test "$HM_TOOLS_DIR" = "/storage/Roms/.portmaster"
if [ -s "$ZLYME_PYTHON_LOG" ]; then
	echo "library helper invoked python3" >&2
	exit 1
fi
echo "portmaster root ok"
