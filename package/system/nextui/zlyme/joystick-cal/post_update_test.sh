#!/bin/sh
set -eu
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/Tools/my355/Autocal.pak" "$root/.config/miyoo-serial-joypad" \
	"$root/.config/zlyme/miyoo-flip-gamepad"
echo old > "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
echo keep > "$root/.config/zlyme/miyoo-flip-gamepad/rumble.config"
hook=$(CDPATH= cd -- "$(dirname "$0")/../../../../../board/my355" && pwd)/post-update.sh
ZLYME_STORAGE_ROOT="$root" /bin/sh "$hook"
test ! -e "$root/Tools/my355/Autocal.pak"
test ! -e "$root/.config/miyoo-serial-joypad"
test ! -e "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
test "$(cat "$root/.config/zlyme/miyoo-flip-gamepad/rumble.config")" = keep
hook=$(CDPATH= cd -- "$(dirname "$0")/../../../../../board/my355" && pwd)/post-update.sh
ZLYME_STORAGE_ROOT="$root" /bin/sh "$hook"
test "$(cat "$root/.config/zlyme/miyoo-flip-gamepad/rumble.config")" = keep
echo POST_UPDATE_OK
