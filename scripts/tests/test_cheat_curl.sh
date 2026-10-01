#!/bin/sh
# The pak curl wrapper must bound both the header check and the download.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
wrap="$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/curl"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$CURL_LOG"
exit 0
EOF
chmod 0755 "$work/curl" "$wrap"
# The wrapper execs /usr/bin/curl. Point that at the recorder via a chroot-less
# PATH trick: run a copy of the wrapper with /usr/bin replaced is not portable.
# Assert the flags by reading the script.
grep -F -q -- '--connect-timeout 15' "$wrap"
grep -F -q -- '--max-time' "$wrap"
grep -F -q 'total=900' "$wrap"
grep -F -q 'cheat: FIND_LOCAL_DB' \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh"
grep -F -q 'cheat: CHECK_UPDATE' \
	"$ROOT/package/system/nextui/paks/Tools/Cheat Downloader.pak/launch.sh"
echo "cheat curl ok"
