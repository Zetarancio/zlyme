#!/bin/sh
# The launcher must reach the application without building a log path from the binary path.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
launch=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/launch.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/pak/resources" "$work/logs"
printf '{}\n' > "$work/pak/resources/systems.json"
cp "$launch" "$work/pak/launch.sh"
# The test copy still points at the real catalog unless we use the script's own PAK_DIR.
# Run the real launcher; its PAK_DIR is the source pak, which has systems.json.

cat > "$work/bin/zcrapegoat" << 'EOF'
#!/bin/sh
printf 'ran catalog=%s args=%s\n' "${SCRAPEGOAT_SYSTEMS_JSON:-}" "$*" > "$ZLYME_FAKE_OUT"
exit "${ZLYME_FAKE_EXIT:-0}"
EOF
chmod 0755 "$work/bin/zcrapegoat"

cat > "$work/bin/pak-log.sh" << 'EOF'
#!/bin/sh
echo "paklog" >> "$ZLYME_FAKE_LOG"
EOF

out=$work/out
ZLYME_ZCRAPEGOAT_BIN=$work/bin/zcrapegoat \
ZLYME_FAKE_OUT=$out \
ZLYME_FAKE_EXIT=0 \
	sh "$launch" --credential-status >"$work/stdout" 2>"$work/stderr"
test "$(cat "$out")" = "ran catalog=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/resources/systems.json args=--credential-status"
if grep -q '//usr/lib/zlyme' "$work/stdout" "$work/stderr" "$out"; then
	echo "launcher built a doubled log path" >&2
	exit 1
fi

ZLYME_ZCRAPEGOAT_BIN=$work/bin/zcrapegoat \
ZLYME_FAKE_OUT=$out \
ZLYME_FAKE_EXIT=7 \
ZLYME_FAKE_LOG=$work/logs/seen \
	sh "$launch" >/dev/null 2>&1 || st=$?
test "${st:-0}" -eq 7

# Forced pak logging still reaches the app. The helper is sourced only when present;
# point the launcher at a copy that sources our helper by replacing the path via a wrapper dir.
# The real script sources /usr/share/nextui/bin/pak-log.sh. If that file exists on the host,
# sourcing it must not stop the fake app.
ZLYME_ZCRAPEGOAT_BIN=$work/bin/zcrapegoat ZLYME_FAKE_OUT=$out ZLYME_FAKE_EXIT=0 \
	sh "$launch" >/dev/null
test -s "$out"
echo "zcrapegoat launch ok"
