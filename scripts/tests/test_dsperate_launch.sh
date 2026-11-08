#!/bin/sh
# DSperate package pin and the NDS launcher. No emulator binary is run.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
mk=$ROOT/package/emulators/dsperate/dsperate.mk
start=$ROOT/package/emulators/dsperate/start_dsperate.sh
launch=$ROOT/package/system/nextui/paks/Emus/NDS.pak/launch.sh
defconfig=$ROOT/configs/zlyme_my355_defconfig
fail() {
	echo "dsperate-launch: $*" >&2
	exit 1
}

[ -f "$mk" ] || fail "recipe missing"
grep -q 'DSPERATE_VERSION = aabc4b065afaf582cbc43c16d579de431b808d57' "$mk" \
	|| fail "source pin moved"
grep -q 'https://github.com/beebono/DSperate.git' "$mk" || fail "upstream moved"
grep -q 'DSPERATE_LICENSE = GPL-3.0-or-later, BSD-2-Clause, OFL-1.1, MIT' "$mk" \
	|| fail "license changed"
grep -q 'src/core/bios/LICENSE.freebios' "$mk" || fail "FreeBIOS notice is not recorded"
grep -q 'LICENSE-NotoSans-OFL-1.1.txt' "$mk" || fail "OFL notice is not recorded"
grep -q 'LICENSE-WenQuanYi-MicroHei.txt' "$mk" || fail "font exception is not recorded"
grep -q 'src/core/cart/miniz/LICENSE' "$mk" || fail "miniz notice is not recorded"
grep -q 'return {};' "$ROOT/package/emulators/dsperate/0001-omit-unlicensed-analog-database.patch" \
	|| fail "the analog database patch does not drop the built-in file"
grep -q 'builtin.empty()' "$ROOT/package/emulators/dsperate/0001-omit-unlicensed-analog-database.patch" \
	|| fail "an empty analog database is still reported as corrupt"
ab=$ROOT/package/emulators/dsperate/0002-flip-ab-defaults.patch
grep -F -q '{"a", "b", "back", "start"' "$ab" || fail "DS A and B are not the virtual pad A and B"
grep -F -q '{"b", "a", "back", "start"' "$ab" || fail "the patch does not replace the upstream A and B defaults"
grep -F -q '"y", "x"' "$ab" || fail "X and Y defaults were not kept"
if grep -q 'face_fix_ = false' "$ab"; then
	fail "the patch disables face correction"
fi
grep -q 'sdl2 alsa-lib' "$mk" || fail "dependencies changed"
grep -q -- '-DDSPERATE_JIT=ON' "$mk" || fail "JIT is off"
grep -q -- '-DDSPERATE_NEON=ON' "$mk" || fail "NEON is off"
grep -q -- '-DDSPERATE_TUNE=-mcpu=cortex-a55' "$mk" || fail "tune is not cortex-a55"
grep -q -- '-DDSPERATE_WAYLAND=OFF' "$mk" || fail "Wayland scanout is on"
grep -q -- '-DDSPERATE_TESTS=OFF' "$mk" || fail "unit tests are on"
grep -q -- '-DDSPERATE_HEADLESS=OFF' "$mk" || fail "headless frontend is on"
grep -q -- '-DDSPERATE_CHEEVOS=OFF' "$mk" || fail "achievements are on"
grep -q -- '-DDSPERATE_NET=OFF' "$mk" || fail "network transports are on"
grep -q -- '-DDSPERATE_PGO=OFF' "$mk" || fail "PGO is on"
grep -q 'BR2_PACKAGE_DSPERATE=y' "$defconfig" || fail "product defconfig omits DSperate"
if grep -q 'BR2_PACKAGE_DRASTIC' "$defconfig"; then
	fail "product defconfig still selects DraStic"
fi
grep -q -- '-DDSPERATE_VULKAN=OFF' "$mk" || fail "Vulkan presenter is on"
grep -q -- '-DDSPERATE_GLES=OFF' "$mk" || fail "GLES raster is on"
[ ! -e "$ROOT/package/emulators/drastic" ] || fail "the DraStic package is still in the tree"
awk '$1=="NDS" { print $2; exit }' "$ROOT/package/system/nextui/emu-defaults.txt" | grep -qx dsperate \
	|| fail "NDS default is not dsperate"
awk -F '\t' '$1=="NDS" { print $2; exit }' "$ROOT/package/system/nextui/emu-paks.txt" | grep -qx start_dsperate \
	|| fail "NDS registry is not start_dsperate"
grep -qx 'NDS: nds zip' "$ROOT/package/system/nextui/rom-exts.txt" || fail "NDS extensions are not nds and zip"
if grep -q 'NDS:.*7z' "$ROOT/package/system/nextui/rom-exts.txt"; then
	fail "NDS still lists 7z"
fi
if grep -q 'start_drastic\|/usr/bin/drastic\|libdrastouch' \
	"$ROOT/board/my355/assert-input-rootfs.sh" \
	"$ROOT/package/system/nextui/zlyme/zlyme-stock-seed" \
	"$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage"; then
	fail "an active product file still requires DraStic"
fi
grep -q 'dsperate' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-storage" \
	|| fail "the storage guard does not watch dsperate"
grep -q 'pak-log.sh' "$launch" || fail "NDS pak dropped system logging"
grep -q 'zlyme-governor emu' "$launch" || fail "NDS pak dropped the governor"
# The quotes are part of the source text.
# shellcheck disable=SC2016
grep -q 'exec start_dsperate "$ROM"' "$launch" || fail "NDS pak does not exec the quoted ROM"
if grep -q 'start_drastic' "$launch"; then
	fail "NDS pak still starts DraStic"
fi
if grep -E -q 'mount |rm -rf|trap ' "$start"; then
	fail "the DSperate launcher mounts, recursively deletes, or traps a signal"
fi
# shellcheck disable=SC2016
grep -q 'exec dsperate "$ROM"' "$start" || fail "the launcher does not exec the ROM"
grep -q -- '--sink kms' "$start" || fail "the sink is not kms"
grep -q -- '--fullscreen' "$start" || fail "the window is not fullscreen"
grep -q -- '--no-gpu-present' "$start" || fail "gpu present is enabled"
grep -q -- '--no-gpu3d' "$start" || fail "gpu 3d is enabled"
grep -q -- '--no-mic' "$start" || fail "the microphone device is opened"
grep -q 'NDS/dsperate' "$start" || fail "saves are not in the DSperate directory"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/card/Saves/NDS/backup" "$work/card/Saves/NDS/savestates" \
	"$work/card/Bios/NDS" "$work/cfg/dsperate" "$work/cfg/drastic" "$work/rom dir"
printf '%s\n' 'drastic-save' > "$work/card/Saves/NDS/backup/keep.dsv"
printf '%s\n' 'drastic-state' > "$work/card/Saves/NDS/savestates/slot.dss"
printf '%s\n' 'drastic-cfg' > "$work/cfg/drastic/drastic.cfg"
printf '%s\n' 'user-cfg' > "$work/cfg/dsperate/dsperate.ini"
printf 'nds' > "$work/rom dir/Age of Empires.nds"
cat > "$work/bin/dsperate" << 'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$@" >> "$ZLYME_DSPERATE_ARGV"
if [ "${1:-}" = --write-config ]; then
	printf '%s\n' seeded > "$2"
fi
exit "${ZLYME_DSPERATE_STATUS:-0}"
EOF
chmod 0755 "$work/bin/dsperate"

run() {
	PATH="$work/bin:$PATH" \
		SDCARD_PATH=$work/card \
		SAVES_PATH=$work/card/Saves \
		BIOS_PATH=$work/card/Bios \
		XDG_CONFIG_HOME=$work/cfg \
		ZLYME_DSPERATE_ARGV=$work/argv \
		sh "$start" "$@"
}

: > "$work/argv"
set +e
run
st=$?
set -e
[ "$st" != 0 ] || fail "a missing rom was accepted"
[ ! -s "$work/argv" ] || fail "a missing rom started the emulator"
cmp -s "$work/card/Saves/NDS/backup/keep.dsv" - << 'EOF' || fail "a missing rom changed a DraStic save"
drastic-save
EOF

: > "$work/argv"
run "$work/rom dir/Age of Empires.nds"
grep -Fxq "$work/rom dir/Age of Empires.nds" "$work/argv" \
	|| fail "the rom path was not passed as one argument"
grep -Fxq "$work/card/Saves/NDS/dsperate" "$work/argv" \
	|| fail "saves were not directed at the DSperate directory"
grep -Fxq "$work/card/Saves/NDS/dsperate/states" "$work/argv" \
	|| fail "states were not directed at the DSperate directory"
grep -Fxq kms "$work/argv" || fail "the sink is not kms"
grep -Fxq -- --fullscreen "$work/argv" || fail "fullscreen was not passed"
grep -Fxq -- --no-gpu-present "$work/argv" || fail "gpu present is enabled"
grep -Fxq -- --no-gpu3d "$work/argv" || fail "gpu 3d is enabled"
grep -Fxq -- --no-mic "$work/argv" || fail "the microphone flag was not passed"
if grep -q -- '--bios9' "$work/argv"; then
	fail "a missing bios was required"
fi
if grep -q -- '--write-config' "$work/argv"; then
	fail "an existing config was rewritten"
fi
cmp -s "$work/cfg/dsperate/dsperate.ini" - << 'EOF' || fail "the user config changed"
user-cfg
EOF
cmp -s "$work/card/Saves/NDS/backup/keep.dsv" - << 'EOF' || fail "a DraStic save changed"
drastic-save
EOF
cmp -s "$work/card/Saves/NDS/savestates/slot.dss" - << 'EOF' || fail "a DraStic state changed"
drastic-state
EOF
cmp -s "$work/cfg/drastic/drastic.cfg" - << 'EOF' || fail "DraStic config changed"
drastic-cfg
EOF

rm -f "$work/cfg/dsperate/dsperate.ini"
: > "$work/argv"
run "$work/rom dir/Age of Empires.nds"
grep -Fxq -- --write-config "$work/argv" || fail "a missing config was not seeded"
grep -Fxq "$work/cfg/dsperate/dsperate.ini" "$work/argv" \
	|| fail "the seed path was not passed"
printf '%s\n' seeded | cmp -s - "$work/cfg/dsperate/dsperate.ini" \
	|| fail "the seed did not write the config"

printf 'bios' > "$work/card/Bios/NDS/bios9.bin"
printf 'bios' > "$work/card/Bios/NDS/bios7.bin"
: > "$work/argv"
run "$work/rom dir/Age of Empires.nds"
grep -Fxq -- --bios9 "$work/argv" || fail "bios9 was not passed"
grep -Fxq "$work/card/Bios/NDS/bios9.bin" "$work/argv" || fail "bios9 path was not passed"
grep -Fxq -- --bios7 "$work/argv" || fail "bios7 was not passed"
grep -Fxq "$work/card/Bios/NDS/bios7.bin" "$work/argv" || fail "bios7 path was not passed"
if grep -q -- '--firmware' "$work/argv"; then
	fail "a missing firmware was passed"
fi

: > "$work/argv"
set +e
ZLYME_DSPERATE_STATUS=143 run "$work/rom dir/Age of Empires.nds"
st=$?
set -e
[ "$st" = 143 ] || fail "a forced emulator exit was swallowed ($st)"
cmp -s "$work/card/Saves/NDS/backup/keep.dsv" - << 'EOF' || fail "termination changed a DraStic save"
drastic-save
EOF

echo "dsperate launch ok"
