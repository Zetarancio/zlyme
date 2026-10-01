#!/bin/sh
# A system is visible only when a launchable game exists.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
src=$ROOT/../zlyme-nextui/workspace/all/nextui/nextui.c
grep -q 'dirHasLaunchable' "$src"
if grep -n 'entryIsDir' "$src" | grep -q 'has = 1'; then
	echo "hasRomsIn still treats a directory as a game" >&2
	exit 1
fi
grep -q 'Create game folders' "$ROOT/../zlyme-nextui/workspace/all/settings/zlymemenu.cpp"
if grep -n 'Zlyme_appendGameFolders' "$ROOT/../zlyme-nextui/workspace/all/settings/settings.cpp" | grep -q gameItems; then
	echo "Create game folders is still under Game" >&2
	exit 1
fi
grep -q 'Zlyme_appendGameFolders(storage)' \
	"$ROOT/../zlyme-nextui/workspace/all/settings/zlymemenu.cpp"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Host stand-in for the C walk. Same rules: ROM file, nested ROM,
# EasyRPG directory. Not an empty directory, .media, or saves.
cat > "$work/visible.py" << 'PY'
import os, sys
JUNK = {".srm",".sav",".state",".png",".jpg",".txt",".nfo"}
JUNK_DIR = {"Imgs","imgs","images","media","artwork","boxart"}
def allowed(name):
    if not name or name[0] in "._":
        return False
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
    if ext in ("swf","p8","gba","zip","m3u"):
        return True
    return False
def easy(path, name):
    if name.endswith(".easyrpg"):
        return True
    return os.path.exists(os.path.join(path, "RPG_RT.ldb")) or os.path.exists(os.path.join(path, "RPG_RT.LDB"))
def walk(path, depth=0):
    if depth > 8 or not os.path.isdir(path):
        return False
    for name in os.listdir(path):
        if name.startswith(".") or name.startswith("_"):
            continue
        full = os.path.join(path, name)
        if os.path.isfile(full) and allowed(name):
            return True
        if not os.path.isdir(full) or os.path.islink(full) and not os.path.isdir(full):
            if os.path.isfile(full):
                continue
        if name in JUNK_DIR:
            continue
        if easy(full, name):
            return True
        if walk(full, depth+1):
            return True
    return False
print("yes" if walk(sys.argv[1]) else "no")
PY
vis() { python3 "$work/visible.py" "$1"; }

mkdir -p "$work/empty/Roms/Flash (FLASH)"
test "$(vis "$work/empty/Roms/Flash (FLASH)")" = no

mkdir -p "$work/saves/Saves/FLASH/flash_data"
test "$(vis "$work/saves/Saves/FLASH")" = no

mkdir -p "$work/nestempty/Roms/Flash (FLASH)/subdir"
test "$(vis "$work/nestempty/Roms/Flash (FLASH)")" = no

mkdir -p "$work/media/Roms/Flash (FLASH)/.media"
printf x > "$work/media/Roms/Flash (FLASH)/.media/a.png"
test "$(vis "$work/media/Roms/Flash (FLASH)")" = no

mkdir -p "$work/swf/Roms/Flash (FLASH)"
printf x > "$work/swf/Roms/Flash (FLASH)/Game.swf"
test "$(vis "$work/swf/Roms/Flash (FLASH)")" = yes

mkdir -p "$work/sub/Roms/Flash (FLASH)/folder"
printf x > "$work/sub/Roms/Flash (FLASH)/folder/Game.swf"
test "$(vis "$work/sub/Roms/Flash (FLASH)")" = yes

mkdir -p "$work/easy/Roms/EasyRPG (EASYRPG)/Quest"
printf x > "$work/easy/Roms/EasyRPG (EASYRPG)/Quest/RPG_RT.ldb"
test "$(vis "$work/easy/Roms/EasyRPG (EASYRPG)")" = yes

mkdir -p "$work/pico/Roms/Pico-8 (PICO)"
printf x > "$work/pico/Roms/Pico-8 (PICO)/000) Splore.p8"
test "$(vis "$work/pico/Roms/Pico-8 (PICO)")" = yes

echo "system visibility ok"
