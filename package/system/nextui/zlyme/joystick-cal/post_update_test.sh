#!/bin/sh
set -eu
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/Tools/my355/Autocal.pak" \
	"$root/Tools/my355/Weston.pak" \
	"$root/Tools/my355/Artwork Scraper.pak" \
	"$root/Tools/my355/Cheat Downloader.pak" \
	"$root/Tools/my355/Files.pak" \
	"$root/Tools/tg5040/Weston.pak" \
	"$root/Cheats" \
	"$root/.config/ScrapeGoat" \
	"$root/Roms/Game Boy (GB)/.media" \
	"$root/.config/miyoo-serial-joypad" \
	"$root/.config/zlyme/miyoo-flip-gamepad"
echo old > "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
echo keep > "$root/.config/zlyme/miyoo-flip-gamepad/rumble.config"
echo user > "$root/Tools/my355/Files.pak/launch.sh"
echo other > "$root/Tools/tg5040/Weston.pak/launch.sh"
echo cht > "$root/Cheats/keep.cht"
echo goat > "$root/.config/ScrapeGoat/settings"
echo art > "$root/Roms/Game Boy (GB)/.media/Tetris.png"
hook=$(CDPATH= cd -- "$(dirname "$0")/../../../../../board/my355" && pwd)/post-update.sh
ZLYME_STORAGE_ROOT="$root" /bin/sh "$hook"
test ! -e "$root/Tools/my355/Autocal.pak"
test ! -e "$root/Tools/my355/Weston.pak"
test ! -e "$root/Tools/my355/Artwork Scraper.pak"
test ! -e "$root/Tools/my355/Cheat Downloader.pak"
test ! -e "$root/.config/miyoo-serial-joypad"
test ! -e "$root/.config/zlyme/rocknix-singleadc-joypad.ko"
test "$(cat "$root/.config/zlyme/miyoo-flip-gamepad/rumble.config")" = keep
test "$(cat "$root/Tools/my355/Files.pak/launch.sh")" = user
test "$(cat "$root/Tools/tg5040/Weston.pak/launch.sh")" = other
test "$(cat "$root/Cheats/keep.cht")" = cht
test "$(cat "$root/.config/ScrapeGoat/settings")" = goat
test "$(cat "$root/Roms/Game Boy (GB)/.media/Tetris.png")" = art
hook=$(CDPATH= cd -- "$(dirname "$0")/../../../../../board/my355" && pwd)/post-update.sh
ZLYME_STORAGE_ROOT="$root" /bin/sh "$hook"
test "$(cat "$root/.config/zlyme/miyoo-flip-gamepad/rumble.config")" = keep
echo POST_UPDATE_OK
