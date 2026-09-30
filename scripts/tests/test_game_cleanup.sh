#!/bin/sh
# Host checks for zlyme-game-cleanup. Does not touch /storage.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CLEAN="$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

libA=$work/libA
libB=$work/libB
mkdir -p "$libA/Roms/GBA" "$libA/Saves/GBA" "$libB/Roms/GBA" "$libB/Saves/GBA"
printf 'rom\n' >"$libA/Roms/GBA/Mario.gba"
printf 'rom\n' >"$libA/Roms/GBA/Game.gba"
printf 'save\n' >"$libA/Saves/GBA/Mario.srm"
printf 'save\n' >"$libA/Saves/GBA/Gone.srm"
printf 'save\n' >"$libA/Saves/GBA/Game.gba.sav"
printf 'save\n' >"$libA/Saves/GBA/Game.state"
printf 'save\n' >"$libA/Saves/GBA/Game.state1"
printf 'save\n' >"$libA/Saves/GBA/Game.state.1"
printf 'save\n' >"$libA/Saves/GBA/Game.st0"
printf 'note\n' >"$libA/Saves/GBA/notes.txt"
printf 'rom\n' >"$libB/Roms/GBA/OnlyB.gba"
printf 'save\n' >"$libA/Saves/GBA/OnlyB.srm"
printf '%s\n%s\n' "$libA" "$libB" >"$work/libraries"

run() {
	ZLYME_LIBRARIES_FILE="$work/libraries" \
	ZLYME_CLEANUP_ROOT="$work/os" \
	ZLYME_DEVICE_CONF= \
		"$CLEAN" "$@"
}

out=$(run orphan-saves --dry-run)
count=$(printf '%s\n' "$out" | awk -F= '/^COUNT=/{print $2; exit}')
[ "$count" = 1 ] || {
	echo "expected 1 orphan, got: $out" >&2
	exit 1
}
for keep in Mario.srm Game.gba.sav Game.state Game.state1 Game.state.1 Game.st0 notes.txt; do
	cmp "$libA/Saves/GBA/$keep" "$libA/Saves/GBA/$keep" >/dev/null
	test -s "$libA/Saves/GBA/$keep"
done

run orphan-saves >/dev/null
test -f "$libA/Saves/GBA/Mario.srm"
test -f "$libA/Saves/GBA/Game.gba.sav"
test -f "$libA/Saves/GBA/Game.state"
test -f "$libA/Saves/GBA/Game.state1"
test -f "$libA/Saves/GBA/Game.state.1"
test -f "$libA/Saves/GBA/Game.st0"
test -f "$libA/Saves/GBA/notes.txt"
test ! -e "$libA/Saves/GBA/Gone.srm"
test -f "$libA/Saves/GBA/OnlyB.srm"
test -f "$libB/Roms/GBA/OnlyB.gba"

# Standalone settings reset. Sentinels are user data.
os=$work/os
pico=$os/.config/nextui/shared/Pico-8-native
mkdir -p "$pico/carts" "$pico/cdata" "$pico/bbs" "$pico/data" "$pico/config" \
	"$os/.config/nextui/my355" \
	"$os/.config/ppsspp/PSP/SYSTEM" \
	"$os/.config/ppsspp/PSP/SAVEDATA" \
	"$os/.config/ppsspp/PSP/PPSSPP_STATE" \
	"$os/.config/nextui/shared/configs/gzdoom/soundfonts" \
	"$os/.config/nextui/shared/configs/gzdoom/fm_banks" \
	"$os/.config/flycast" \
	"$os/.config/nextui/my355/.local/share/flycast" \
	"$os/.config/dolphin-emu" \
	"$os/.config/nextui/my355/.local/share/dolphin-emu/GC" \
	"$os/.config/drastic" \
	"$os/.config/aethersx2/inis" \
	"$os/.config/aethersx2/cache"
printf 'cart\n' >"$pico/carts/user.p8"
printf 'cdata\n' >"$pico/cdata/keep"
printf 'bbs\n' >"$pico/bbs/keep"
printf 'data\n' >"$pico/data/keep"
printf 'cfg\n' >"$pico/config/config.txt"
printf 'pad\n' >"$pico/sdl_controllers.txt"
printf 'marker\n' >"$pico/splore-installed"
printf 'wine-image\n' >"$os/.config/nextui/my355/wine-prefix.ext4"
mkdir -p "$os/.config/nextui/my355/wine"
printf 'unclear\n' >"$os/.config/nextui/my355/wine/keep"
printf 'sav\n' >"$os/.config/ppsspp/PSP/SAVEDATA/GAME"
printf 'state\n' >"$os/.config/ppsspp/PSP/PPSSPP_STATE/slot"
printf 'ini\n' >"$os/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
printf 'sf\n' >"$os/.config/nextui/shared/configs/gzdoom/soundfonts/user.sf2"
printf 'fm\n' >"$os/.config/nextui/shared/configs/gzdoom/fm_banks/user.opn"
printf 'ini\n' >"$os/.config/nextui/shared/configs/gzdoom/gzdoom.ini"
printf 'exec\n' >"$os/.config/nextui/shared/configs/gzdoom/autoexec.cfg"
printf 'cfg\n' >"$os/.config/flycast/emu.cfg"
printf 'vmu\n' >"$os/.config/nextui/my355/.local/share/flycast/vmu.bin"
printf 'ini\n' >"$os/.config/dolphin-emu/Dolphin.ini"
printf 'mem\n' >"$os/.config/nextui/my355/.local/share/dolphin-emu/GC/card.raw"
printf 'cfg\n' >"$os/.config/drastic/drastic.cfg"
printf 'ini\n' >"$os/.config/aethersx2/inis/PCSX2.ini"
printf 'cache\n' >"$os/.config/aethersx2/cache/keep"

dry=$(run standalones --dry-run)
printf '%s\n' "$dry" | awk -F= '/^COUNT=/{if ($2+0 < 1) exit 1}'
test -f "$pico/carts/user.p8"
test -f "$os/.config/nextui/my355/wine-prefix.ext4"
test -f "$os/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

run standalones >/dev/null
test -f "$pico/carts/user.p8"
test -f "$pico/cdata/keep"
test -f "$pico/bbs/keep"
test -f "$pico/data/keep"
test -f "$pico/splore-installed"
test ! -e "$pico/config"
test ! -e "$pico/sdl_controllers.txt"
test -f "$os/.config/nextui/my355/wine-prefix.ext4"
test -f "$os/.config/nextui/my355/wine/keep"
test -f "$os/.config/ppsspp/PSP/SAVEDATA/GAME"
test -f "$os/.config/ppsspp/PSP/PPSSPP_STATE/slot"
test ! -e "$os/.config/ppsspp/PSP/SYSTEM"
test -f "$os/.config/nextui/shared/configs/gzdoom/soundfonts/user.sf2"
test -f "$os/.config/nextui/shared/configs/gzdoom/fm_banks/user.opn"
test -f "$os/.config/nextui/shared/configs/gzdoom/autoexec.cfg"
test ! -e "$os/.config/nextui/shared/configs/gzdoom/gzdoom.ini"
test ! -e "$os/.config/flycast"
test -f "$os/.config/nextui/my355/.local/share/flycast/vmu.bin"
test ! -e "$os/.config/dolphin-emu"
test -f "$os/.config/nextui/my355/.local/share/dolphin-emu/GC/card.raw"
test ! -e "$os/.config/drastic/drastic.cfg"
test ! -e "$os/.config/aethersx2/inis"
test -f "$os/.config/aethersx2/cache/keep"

# A failing rm must not look like success.
bindir=$work/bin
mkdir -p "$bindir"
cat >"$bindir/rm" <<'EOF'
#!/bin/sh
echo "$*" | grep -q 'ppsspp/PSP/SYSTEM' && exit 1
exec /bin/rm "$@"
EOF
chmod 0755 "$bindir/rm"
mkdir -p "$os/.config/ppsspp/PSP/SYSTEM"
printf 'ini\n' >"$os/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
if PATH="$bindir:$PATH" ZLYME_LIBRARIES_FILE="$work/libraries" \
	ZLYME_CLEANUP_ROOT="$work/os" ZLYME_DEVICE_CONF= \
	"$CLEAN" standalones >/dev/null; then
	echo "failed deletion was reported as success" >&2
	exit 1
fi
test -f "$os/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

# Indexed scan versus one grep per save. Same fixture, same orphans.
bench=$work/bench
mkdir -p "$bench/Roms/GBA" "$bench/Saves/GBA"
i=0
while [ "$i" -lt 5000 ]; do
	printf 'r\n' >"$bench/Roms/GBA/g$i.gba"
	printf 's\n' >"$bench/Saves/GBA/g$i.srm"
	i=$((i + 1))
done
i=0
while [ "$i" -lt 500 ]; do
	printf 'o\n' >"$bench/Saves/GBA/orphan$i.srm"
	i=$((i + 1))
done
printf '%s\n' "$bench" >"$work/bench-libs"

old_orphans() {
	stems=$(find "$bench/Roms" -type f | while IFS= read -r f; do
		b=$(basename "$f")
		stem=${b%.*}
		printf '%s\n' "$stem"
	done)
	find "$bench/Saves" -type f -name '*.srm' | while IFS= read -r f; do
		b=$(basename "$f")
		stem=${b%.*}
		printf '%s\n' "$stems" | grep -Fxq "$stem" && continue
		printf '%s\n' "$f"
	done
}

now_ns() { date +%s%N; }
t0=$(now_ns)
old_n=$(old_orphans | wc -l | tr -d ' ')
t1=$(now_ns)
old_ms=$(( (t1 - t0) / 1000000 ))
t2=$(now_ns)
new_out=$(ZLYME_LIBRARIES_FILE="$work/bench-libs" ZLYME_CLEANUP_ROOT="$work/os" \
	ZLYME_DEVICE_CONF= "$CLEAN" orphan-saves --dry-run)
t3=$(now_ns)
new_ms=$(( (t3 - t2) / 1000000 ))
new_n=$(printf '%s\n' "$new_out" | awk -F= '/^COUNT=/{print $2; exit}')
[ "$old_n" = 500 ] || {
	echo "old scan count $old_n" >&2
	exit 1
}
[ "$new_n" = 500 ] || {
	echo "new scan count $new_n" >&2
	exit 1
}
test -f "$bench/Saves/GBA/g0.srm"
test -f "$bench/Saves/GBA/orphan0.srm"
echo "orphan-scan old=${old_ms}ms new=${new_ms}ms count=$new_n stems-in-shell=yes-for-old-only"
if [ "$new_ms" -ge "$old_ms" ]; then
	echo "indexed scan was slower than the per-file grep" >&2
	exit 1
fi

echo "game cleanup ok"
