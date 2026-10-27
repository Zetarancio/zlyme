#!/bin/sh
# Session joypad choice: udev for one virtual pad, SDL2 otherwise.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "ra-udev: $*" >&2; exit 1; }
RA=$ROOT/package/system/nextui/zlyme/ra-run.sh
STOCK=$ROOT/board/my355/fsoverlay/usr/share/zlyme/retroarch/retroarch.cfg
UDEV=$ROOT/board/my355/fsoverlay/usr/share/retroarch/autoconfig/udev/Microsoft\ X-Box\ 360\ pad.cfg
SDL=$ROOT/package/emulators/retroarch/zlyme/autoconfig/sdl2/Microsoft\ X-Box\ 360\ pad.cfg

grep -q 'input_joypad_driver = "udev"' "$STOCK" || fail "stock joypad driver is not udev"
grep -q 'input_driver = "sdl2"' "$STOCK" || fail "stock general input driver changed"
grep -q 'input_player1_reserved_device = "Microsoft X-Box 360 pad"' "$STOCK" \
	|| fail "stock does not reserve the virtual pad name"
grep -q 'input_player1_device_reservation_type = "2"' "$STOCK" \
	|| fail "stock reservation is not reserved"
if grep -q 'input_menu_toggle_btn = "5"' "$STOCK"; then
	fail "stock still pins the SDL guide button"
fi
grep -q 'input_a_btn = "0"' "$UDEV" || fail "udev A is not east"
grep -q 'input_b_btn = "1"' "$UDEV" || fail "udev B is not south"
grep -q 'input_x_btn = "2"' "$UDEV" || fail "udev X is not north"
grep -q 'input_y_btn = "3"' "$UDEV" || fail "udev Y is not west"
grep -q 'input_menu_toggle_btn = "8"' "$UDEV" || fail "udev menu is not guide"
grep -q 'input_l_btn = "4"' "$UDEV" || fail "udev L changed"
grep -q 'input_r_btn = "5"' "$UDEV" || fail "udev R changed"
grep -q 'input_l_x_plus_axis = "+0"' "$UDEV" || fail "udev left stick changed"
grep -q 'input_r_x_plus_axis = "+3"' "$UDEV" || fail "udev right stick changed"
grep -q 'input_up_btn = "h0up"' "$UDEV" || fail "udev d-pad changed"
grep -q 'joypad_autoconfig_dir = "/usr/share/retroarch/autoconfig"' "$STOCK" \
	|| fail "stock autoconfig directory changed"
grep -q 'input_enable_hotkey_btn = "nul"' "$STOCK" \
	|| fail "stock hotkey button is no longer disabled"
if grep -q 'input_menu_toggle_btn' "$RA"; then
	fail "ra-run writes a menu button"
fi
grep -q '/usr/share/retroarch/autoconfig' "$RA" || fail "ra-run lost the autoconfig directory"
grep -q 'input_driver = "sdl2"' "$SDL" || fail "SDL profile was removed"
if grep -q 'input_menu_toggle_btn = "8"' "$SDL"; then
	fail "SDL profile now uses the udev guide index"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sys=$work/sys
mkdir -p "$work/bin" "$work/cfg/retroarch" "$work/bios" "$work/card"
cat > "$work/bin/retroarch" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$ZLYME_TEST_RA_ARGS"
exit 0
EOF
chmod 0755 "$work/bin/retroarch"
mkdir -p "$work/cfg/retroarch/config/Gambatte"
printf '%s\n' 'input_player1_a = "x"' > "$work/cfg/retroarch/config/Gambatte/game.rmp"
remap=$(cksum "$work/cfg/retroarch/config/Gambatte/game.rmp")
: > "$work/cfg/retroarch/retroarch.cfg"
printf '%s\n' 'keep-user' >> "$work/cfg/retroarch/retroarch.cfg"
before=$(cksum "$work/cfg/retroarch/retroarch.cfg")

pad() {
	_id=$1
	_name=$2
	_virt=$3
	mkdir -p "$sys/input$_id"
	printf '%s\n' "$_name" > "$sys/input$_id/name"
	if [ "$_virt" = 1 ]; then
		mkdir -p "$work/sysroot/devices/virtual/input$_id"
		ln -s "$work/sysroot/devices/virtual/input$_id" "$sys/input$_id/device"
	else
		mkdir -p "$work/sysroot/devices/platform/input$_id"
		ln -s "$work/sysroot/devices/platform/input$_id" "$sys/input$_id/device"
	fi
}

run() {
	rm -f "$work/args" "$work/ac"
	PATH=$work/bin:/usr/bin:/bin \
		ZLYME_INPUT_SYS=$sys \
		ZLYME_UDEV_DATA=${ZLYME_UDEV_DATA:-$work/nodev} \
		ZLYME_TEST_RA_ARGS=$work/args \
		XDG_CONFIG_HOME=$work/cfg \
		BIOS_PATH=$work/bios \
		SDCARD_PATH=$work/card \
		HOME=$work/home \
		sh "$RA" >/dev/null
}

pad 4 "Miyoo Flip Gamepad" 0
pad 5 "Microsoft X-Box 360 pad" 1
run
grep -q 'input_joypad_driver = "sdl2"' /tmp/zlyme-ra-ac.cfg \
	|| fail "a virtual pad without a joystick event selected udev"
grep -q 'input_player1_joypad_index = "0"' /tmp/zlyme-ra-ac.cfg \
	|| fail "the unresolved case lost the SDL index"
after=$(cksum "$work/cfg/retroarch/retroarch.cfg")
[ "$before" = "$after" ] || fail "ra-run wrote the user configuration"
[ "$remap" = "$(cksum "$work/cfg/retroarch/config/Gambatte/game.rmp")" ] \
	|| fail "ra-run changed a core remap"
grep -q 'joypad_autoconfig_dir = "/usr/share/retroarch/autoconfig"' /tmp/zlyme-ra-ac.cfg \
	|| grep -q 'joypad_autoconfig_dir = "/usr/share/zlyme/retroarch/autoconfig"' /tmp/zlyme-ra-ac.cfg \
	|| fail "session autoconfig directory is missing"
if grep -q 'input_menu_toggle_btn\|input_exit_emulator_btn' /tmp/zlyme-ra-ac.cfg; then
	fail "session claims MENU or the exit button"
fi

pad 6 "Microsoft X-Box 360 pad" 1
run
grep -q 'input_joypad_driver = "sdl2"' /tmp/zlyme-ra-ac.cfg \
	|| fail "two virtual pads did not fall back to sdl2"
grep -q 'input_player1_device_reservation_type = "0"' /tmp/zlyme-ra-ac.cfg \
	|| fail "the sdl2 fallback left a reservation"
grep -q 'input_player1_joypad_index = "0"' /tmp/zlyme-ra-ac.cfg \
	|| fail "the sdl2 fallback lost index 0"

rm -rf "$sys/input6"
run
grep -q 'input_joypad_driver = "sdl2"' /tmp/zlyme-ra-ac.cfg \
	|| fail "a pad without a joystick event returned to udev"

pad 7 "Microsoft X-Box 360 pad" 0
run
grep -q 'input_joypad_driver = "sdl2"' /tmp/zlyme-ra-ac.cfg \
	|| fail "a same-name physical pad stayed on udev"

rm -rf "$sys"
mkdir -p "$sys"
pad 4 "Miyoo Flip Gamepad" 0
run
grep -q 'input_joypad_driver = "sdl2"' /tmp/zlyme-ra-ac.cfg \
	|| fail "no virtual pad selected udev"

# Live shape: input5 -> /devices/virtual/input/input5, no device
# symlink. event5/device points at that node. udev data marks both
# event nodes as joysticks. eudev orders those syspaths with memcmp.
real=$work/real
db=$work/udev
mkdir -p "$real/devices/virtual/input/input5" \
	"$real/devices/platform/serial/input4/event4" \
	"$real/devices/virtual/input/input5/event5" \
	"$real/class" "$db"
printf '%s\n' "Microsoft X-Box 360 pad" > "$real/devices/virtual/input/input5/name"
printf '%s\n' "Miyoo Flip Gamepad" > "$real/devices/platform/serial/input4/name"
printf '%s\n' '13:68' > "$real/devices/platform/serial/input4/event4/dev"
printf '%s\n' '13:69' > "$real/devices/virtual/input/input5/event5/dev"
printf '%s\n' 'E:ID_INPUT_JOYSTICK=1' > "$db/c13:68"
printf '%s\n' 'E:ID_INPUT_JOYSTICK=1' > "$db/c13:69"
ln -s "$real/devices/virtual/input/input5" "$real/class/input5"
ln -s "$real/devices/platform/serial/input4" "$real/class/input4"
ln -s "$real/devices/platform/serial/input4" \
	"$real/devices/platform/serial/input4/event4/device"
ln -s "$real/devices/virtual/input/input5" \
	"$real/devices/virtual/input/input5/event5/device"
ln -s "$real/devices/platform/serial/input4/event4" "$real/class/event4"
ln -s "$real/devices/virtual/input/input5/event5" "$real/class/event5"
if [ -e "$real/class/input5/device" ]; then
	fail "the real-shape fixture invented an input device symlink"
fi
sys=$real/class
ZLYME_UDEV_DATA=$db
run
unset ZLYME_UDEV_DATA
grep -q 'input_joypad_driver = "udev"' /tmp/zlyme-ra-ac.cfg \
	|| fail "the live-shaped virtual pad did not select udev"
grep -q 'input_player1_joypad_index = "1"' /tmp/zlyme-ra-ac.cfg \
	|| fail "player 1 was not the virtual pad's udev slot"
rm -f "$db/c13:69"
run
grep -q 'input_joypad_driver = "sdl2"' /tmp/zlyme-ra-ac.cfg \
	|| fail "a missing joystick record still selected udev"

echo "ra udev ok"
