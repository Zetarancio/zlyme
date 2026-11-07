#!/bin/sh
# Argument bytes through the Wine launch chain. This does not start
# Weston, Box64, or Wine, and it does not prepare a prefix.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LAUNCH=$ROOT/package/system/nextui/paks/Emus/WINE.pak/launch.sh
WINE_SH=$ROOT/package/emulators/wine-amd64/wine.sh
fail() { echo "wine-utf8: $*" >&2; exit 1; }

[ -f "$LAUNCH" ] || fail "launcher missing"
[ -f "$WINE_SH" ] || fail "wine wrapper missing"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bin=$work/bin
mkdir -p "$bin" "$work/bios" "$work/saves" "$work/userdata" "$work/prefix"

cat > "$bin/zlyme-wine-prefix" << 'EOF'
#!/bin/sh
[ "${1:-}" = prepare ] || exit 2
printf '%s\n' "$ZLYME_TEST_PREFIX"
EOF

cat > "$bin/zlyme-weston-run" << 'EOF'
#!/bin/sh
printf 'weston\n' >> "$ZLYME_TEST_LOG"
exec "$@"
EOF

cat > "$bin/box64" << 'EOF'
#!/bin/sh
{
	printf 'box64 %s\n' "$#"
	i=0
	for arg in "$@"; do
		printf 'arg %s ' "$i"
		printf '%s' "$arg" | od -An -tx1 | tr -d ' \n'
		printf '\n'
		i=$((i + 1))
	done
} >> "$ZLYME_TEST_LOG"
exit 0
EOF
cp "$WINE_SH" "$bin/wine"
chmod 0755 "$bin/zlyme-wine-prefix" "$bin/zlyme-weston-run" "$bin/box64" "$bin/wine"

ascii=$work/ascii-dir
utf8=$work/大富翁4超时空之旅-zhm86平衡修改版20241209
mkdir -p "$ascii" "$utf8"
printf 'ZLYMEEXE\n' > "$ascii/game.exe"
cp -a "$ascii/game.exe" "$utf8/game.exe"
ascii_sum=$(sha256sum "$ascii/game.exe" | awk '{print $1}')
utf8_sum=$(sha256sum "$utf8/game.exe" | awk '{print $1}')
[ "$ascii_sum" = "$utf8_sum" ] || fail "file contents differ"
[ "$(stat -c '%a' "$ascii/game.exe")" = "$(stat -c '%a' "$utf8/game.exe")" ] || fail "modes differ"

hex() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }

run_case() {
	label=$1
	rom=$2
	log=$work/$label.log
	: > "$log"
	PATH="$bin:$PATH" \
	ZLYME_TEST_PREFIX=$work/prefix \
	ZLYME_TEST_LOG=$log \
	BIOS_PATH=$work/bios \
	SAVES_PATH=$work/saves \
	USERDATA_PATH=$work/userdata \
	sh "$LAUNCH" "$rom" || fail "$label launcher status"
	grep -qx weston "$log" || fail "$label did not reach the weston argument pass"
	got=$(awk '/^arg 1 / { print $3 }' "$log")
	[ "$got" = "$(hex "$rom")" ] || fail "$label argument bytes are $got"
	loader=$(awk '/^arg 0 / { print $3 }' "$log")
	[ "$loader" = "$(hex /usr/lib/wine-amd64/bin/wine)" ] || fail "$label loader path"
	[ -d "$work/prefix" ] || fail "$label prefix directory missing"
	if find "$work/prefix" -mindepth 1 -print | grep -q .; then
		fail "$label wrote prefix files"
	fi
}

run_case ascii "$ascii/game.exe"
run_case utf8 "$utf8/game.exe"
echo "wine utf8 args ok"
echo "utf8 dir $(hex "$utf8")"
echo "LANG=${LANG-<unset>} LC_ALL=${LC_ALL-<unset>}"
