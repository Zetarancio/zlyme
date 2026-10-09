#!/bin/sh
# Writable PortMaster live tree: seed, repeat, direct launch, reset, failure.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PREPARE=$ROOT/package/system/portmaster/zlyme-portmaster-prepare
ROOTBIN=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-portmaster-root
RESET=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-reset
LAUNCH=$ROOT/package/system/portmaster/portmaster-launch
OVERLAY=$ROOT/package/system/portmaster

fail() {
	echo "portmaster-prepare: $*" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$work/seed.zip" << 'PY'
import json
import sys
import zipfile

seed = sys.argv[1]
hardware = """
    ('miyoo rk3566 355 v10*', 'miyoo-flip'),
    "Anbernic RG353 M/V/P": {"device": "rg353m"},
"""
platform = "    'rocknix':   PlatformROCKNIX,\n"
theme = {
    "#info": {"name": "Default Theme", "default-scheme": "Light Mode"},
    "#schemes": {
        "Darkest Mode": {
            "#pallet": {
                "background": [0, 0, 0, 255],
                "list_text": [255, 255, 255, 255],
                "list_selected": [153, 180, 255, 255],
                "list_unselectable": [200, 0, 0, 255],
                "selection-fill": [50, 80, 155],
            }
        }
    },
}
pylibs = zipfile.ZipFile(seed + ".pylibs", "w")
pylibs.writestr("pylibs/harbourmaster/hardware.py", hardware)
pylibs.writestr("pylibs/harbourmaster/platform.py", platform)
pylibs.writestr("pylibs/default_theme/theme.json", json.dumps(theme))
pylibs.close()
outer = zipfile.ZipFile(seed, "w")
outer.writestr("PortMaster/pugwash", "seed-pugwash\n")
outer.writestr("PortMaster/harbourmaster", "seed-harbour\n")
outer.writestr("PortMaster/gamecontrollerdb.txt", "db\n")
outer.write(seed + ".pylibs", "PortMaster/pylibs.zip")
love = zipfile.ZipInfo("PortMaster/runtimes/love_11.5/love.aarch64")
love.external_attr = 0o100644 << 16
outer.writestr(love, b"love")
outer.writestr("PortMaster/libs/.keep", "")
outer.close()
PY

storage=$work/storage
sd2=$work/sd2
mkdir -p "$storage" "$sd2" "$work/opt/system/Tools" "$work/cfg"
ln -sfn "$work/run/PortMaster" "$work/opt/system/Tools/PortMaster"
printf '%s\n' "$storage" "$sd2" > "$work/libraries"

overlay=$work/overlay
mkdir -p "$overlay"
ln -sfn "$OVERLAY/control.txt" "$overlay/control.txt"
ln -sfn "$OVERLAY/mod_Zlyme.txt" "$overlay/mod_Zlyme.txt"
ln -sfn "$OVERLAY/patch-hardware.py" "$overlay/patch-hardware.py"
ln -sfn "$OVERLAY/zlyme-theme/inject-scheme.py" "$overlay/inject-scheme.py"
ln -sfn "$OVERLAY/zlyme-theme/select-scheme.py" "$overlay/select-scheme.py"
export ZLYME_PM_SEED=$work/seed.zip
export ZLYME_PM_OVERLAY=$overlay
export ZLYME_PM_RUN=$work/run
export ZLYME_PM_ROOT_BIN=$ROOTBIN
export ZLYME_PM_STORAGE=$storage
export ZLYME_PM_FLAG=$work/flag
export ZLYME_LIBRARIES_FILE=$work/libraries
export ZLYME_CFG=$work/cfg
export ZLYME_PM_MIN_FREE_KB=1
export ZLYME_PM_NO_SLEEP=1
unset ZLYME_PM_LEGACY

"$ROOTBIN" set "$storage"
"$PREPARE"
live=$storage/Roms/.portmaster/PortMaster
test -f "$live/pugwash"
test -d "$live/pylibs/harbourmaster"
test ! -f "$live/pylibs.zip"
test -d "$live/libs"
test ! -L "$live/libs"
test -d "$live/runtimes"
test ! -L "$live/runtimes"
test -f "$live/runtimes/love_11.5/love.aarch64"
test -x "$live/runtimes/love_11.5/love.aarch64"
grep -q 'export CFW_NAME=Zlyme' "$live/control.txt"
grep -q 'mod_Zlyme' "$live/mod_Zlyme.txt" || test -f "$live/mod_Zlyme.txt"
grep -q 'Miyoo Flip' "$live/pylibs/harbourmaster/hardware.py"
grep -q "'zlyme':" "$live/pylibs/harbourmaster/platform.py"
python3 - "$live/pylibs/default_theme/theme.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["#info"]["default-scheme"] == "Zlyme"
assert data["#schemes"]["Zlyme"]["#pallet"]["list_selected"][:3] == [252, 156, 20]
PY
test "$(readlink "$work/run/PortMaster")" = "$live"
test -f "$work/opt/system/Tools/PortMaster/pugwash"
test -f "$work/cfg/PortMaster/control.txt"
grep -q 'export CFW_NAME=Zlyme' "$work/cfg/PortMaster/control.txt"

# Repeat prepare keeps a newer upstream file and user runtime bytes.
printf '%s\n' 'newer-pugwash' > "$live/pugwash"
printf '%s\n' 'user-runtime' > "$live/libs/user-runtime.squashfs"
"$PREPARE"
grep -q 'newer-pugwash' "$live/pugwash"
grep -q 'user-runtime' "$live/libs/user-runtime.squashfs"
grep -q 'export CFW_NAME=Zlyme' "$live/control.txt"

# Direct port path: empty /run still resolves through the same prepare.
rm -rf "$work/run"
"$PREPARE"
test -f "$work/opt/system/Tools/PortMaster/libs/user-runtime.squashfs"
test -f "$work/opt/system/Tools/PortMaster/runtimes/love_11.5/love.aarch64"
test ! -e "$work/run/libs"

# A real directory or file at the runtime path is replaced by the link.
# It must not be used as the live tree, and the live files stay put.
rm -f "$work/run/PortMaster"
mkdir -p "$work/run/PortMaster"
printf '%s\n' 'decoy' > "$work/run/PortMaster/pugwash"
"$PREPARE"
test -L "$work/run/PortMaster"
test "$(readlink "$work/run/PortMaster")" = "$live"
grep -q 'newer-pugwash' "$work/run/PortMaster/pugwash"
test ! -d "$work/run/PortMaster/PortMaster"
rm -f "$work/run/PortMaster"
printf '%s\n' 'stale-file' > "$work/run/PortMaster"
"$PREPARE"
test -L "$work/run/PortMaster"
test "$(readlink "$work/run/PortMaster")" = "$live"
grep -q 'newer-pugwash' "$live/pugwash"

# Selected SD2 does not use the OS card.
"$ROOTBIN" set "$sd2"
"$PREPARE"
sdlive=$sd2/Roms/.portmaster/PortMaster
test -f "$sdlive/pugwash"
test ! -f "$sd2/Roms/.portmaster/../.portmaster" || true
test "$(readlink "$work/run/PortMaster")" = "$sdlive"
test -d "$sdlive/libs"
# The storage install is left where it was. This prepare did not replace it.
grep -q 'newer-pugwash' "$live/pugwash"

# Missing selected disk does not fall back.
rm -rf "$sd2"
if "$PREPARE" >"$work/out" 2>"$work/err"; then
	fail "missing disk prepared a tree"
fi
grep -q 'not inserted' "$work/err"
test ! -s "$work/out"
grep -q 'newer-pugwash' "$live/pugwash"
test ! -d "$storage/Roms/.portmaster/PortMaster.missing" 

# Migration keeps card libs and retires the legacy launcher copy.
# Legacy config and the obsolete Zlyme theme directory are merged before
# the final integration pass, which is what normalizes them.
mkdir -p "$storage/PortMaster/PortMaster/libs" \
	"$storage/PortMaster/PortMaster/config" \
	"$storage/PortMaster/PortMaster/themes/Zlyme" \
	"$storage/PortMaster/PortMaster/runtimes"
printf '%s\n' 'legacy-lib' > "$storage/PortMaster/PortMaster/libs/legacy.squashfs"
printf '%s\n' 'legacy-runtime' > "$storage/PortMaster/PortMaster/runtimes/legacy.squashfs"
printf '%s\n' 'obsolete-theme' > "$storage/PortMaster/PortMaster/themes/Zlyme/theme.txt"
python3 - "$storage/PortMaster/PortMaster/config/config.json" << 'PY'
import json, sys
json.dump({"theme": "Zlyme", "theme-scheme": "old"}, open(sys.argv[1], "w"))
PY
printf '%s\n' 'seed-pugwash' > "$live/pugwash"
printf '%s\n' 'upstream-control' > "$live/control.txt"
python3 - "$live/pylibs/default_theme/theme.json" << 'PY'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
data["#info"]["default-scheme"] = "Light Mode"
data["#schemes"].pop("Zlyme", None)
json.dump(data, open(p, "w"))
PY
# live is already valid, so the engine stays and legacy state is merged.
"$ROOTBIN" set "$storage"
"$PREPARE"
grep -q 'legacy-lib' "$live/libs/legacy.squashfs"
grep -q 'legacy-runtime' "$live/runtimes/legacy.squashfs"
test ! -e "$storage/PortMaster"
test ! -e "$live/themes/Zlyme"
grep -q 'seed-pugwash' "$live/pugwash"
grep -q 'export CFW_NAME=Zlyme' "$live/control.txt"
grep -q 'Miyoo Flip' "$live/pylibs/harbourmaster/hardware.py"
grep -q "'zlyme':" "$live/pylibs/harbourmaster/platform.py"
python3 - "$live/config/config.json" "$live/pylibs/default_theme/theme.json" << 'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
assert cfg.get("theme") == "default_theme", cfg
assert cfg.get("theme-scheme") == "Zlyme", cfg
theme = json.load(open(sys.argv[2]))
assert theme["#info"]["default-scheme"] == "Zlyme"
assert theme["#schemes"]["Zlyme"]["#pallet"]["list_selected"][:3] == [252, 156, 20]
PY

# A theme the user actually selected is left alone.
python3 - "$live/config/config.json" << 'PY'
import json, sys
json.dump({"theme": "Synth", "theme-scheme": "Night"}, open(sys.argv[1], "w"))
PY
"$PREPARE"
python3 - "$live/config/config.json" << 'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
assert cfg.get("theme") == "Synth", cfg
assert cfg.get("theme-scheme") == "Night", cfg
PY
test ! -e "$live/themes/Zlyme"

# Reset removes the application and keeps a port.
mkdir -p "$storage/Roms/Ports (PORTS)/fixture" "$work/cfg/portmaster-home"
printf '%s\n' '#!/bin/sh' > "$storage/Roms/Ports (PORTS)/fixture/Fixture.sh"
printf '%s\n' 'home' > "$work/cfg/portmaster-home/keep"
printf '%s\n' 'wifi' > "$work/cfg/wpa_supplicant.conf"
ZLYME_RESET_ROOT=$work \
ZLYME_PM_STORAGE=$storage \
ZLYME_PM_FLAG=$work/flag \
ZLYME_LIBRARIES_FILE=$work/libraries \
ZLYME_PM_ROOT_BIN=$ROOTBIN \
ZLYME_CFG=$work/cfg \
	"$RESET" portmaster
test ! -e "$live"
test ! -e "$work/cfg/PortMaster"
test ! -e "$work/cfg/portmaster-home"
grep -q '#!/bin/sh' "$storage/Roms/Ports (PORTS)/fixture/Fixture.sh"
grep -q wifi "$work/cfg/wpa_supplicant.conf"

# The next prepare installs the seed again.
"$PREPARE"
test -f "$live/pugwash"
grep -q 'seed-pugwash' "$live/pugwash"
grep -q '#!/bin/sh' "$storage/Roms/Ports (PORTS)/fixture/Fixture.sh"

# A corrupt seed does not publish a live tree.
bad=$work/badstorage
mkdir -p "$bad"
printf '%s\n' "$bad" >> "$work/libraries"
"$ROOTBIN" set "$bad"
printf '%s\n' 'not a zip' > "$work/bad.zip"
ZLYME_PM_SEED=$work/bad.zip "$PREPARE" >"$work/out" 2>"$work/err" && fail "corrupt seed succeeded"
grep -q 'could not be installed' "$work/err"
test ! -e "$bad/Roms/.portmaster/PortMaster"
test ! -d "$bad/Roms/.portmaster/.pm-stage."* 

# Not enough space does not publish.
ZLYME_PM_SEED=$work/seed.zip ZLYME_PM_MIN_FREE_KB=999999999 \
	"$PREPARE" >"$work/out" 2>"$work/err" && fail "tiny filesystem succeeded"
grep -q 'Not enough free space' "$work/err"
test ! -e "$bad/Roms/.portmaster/PortMaster"

# Integration refresh, then a tree whose hardware patch cannot apply.
"$ROOTBIN" set "$storage"
export ZLYME_PM_MIN_FREE_KB=1
export ZLYME_PM_SEED=$work/seed.zip
"$PREPARE"
printf '%s\n' 'upstream-control' > "$live/control.txt"
printf '%s\n' 'keep-runtime' > "$live/libs/keep.squashfs"
python3 - "$live/pylibs/default_theme/theme.json" << 'PY'
import json, sys
p = sys.argv[1]
data = json.load(open(p))
data["#info"]["default-scheme"] = "Light Mode"
data["#schemes"].pop("Zlyme", None)
json.dump(data, open(p, "w"))
PY
python3 - "$live/pylibs/harbourmaster/hardware.py" << 'PY'
import sys
open(sys.argv[1], "w").write(
    "    ('miyoo rk3566 355 v10*', 'miyoo-flip'),\n"
    '    "Anbernic RG353 M/V/P": {"device": "rg353m"},\n'
)
open(sys.argv[1].rsplit("/", 1)[0] + "/platform.py", "w").write(
    "    'rocknix':   PlatformROCKNIX,\n"
)
PY
"$PREPARE"
grep -q 'export CFW_NAME=Zlyme' "$live/control.txt"
grep -q 'Miyoo Flip' "$live/pylibs/harbourmaster/hardware.py"
grep -q 'keep-runtime' "$live/libs/keep.squashfs"
python3 - "$live/pylibs/default_theme/theme.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert "Zlyme" in data["#schemes"]
PY

printf '%s\n' 'not-hardware' > "$live/pylibs/harbourmaster/hardware.py"
if "$PREPARE" >"$work/out" 2>"$work/err"; then
	fail "incompatible hardware was accepted"
fi
grep -q 'could not be applied' "$work/err"
grep -q 'not-hardware' "$live/pylibs/harbourmaster/hardware.py"
grep -q 'keep-runtime' "$live/libs/keep.squashfs"

# Upstream restart: the flag survives until the wrapper has prepared again.
printf '%s\n' 'seed-pugwash' > "$live/pugwash"
# Restore a patchable tree so prepare can succeed inside the launcher.
"$ROOTBIN" set "$storage"
python3 - "$live/pylibs/harbourmaster/hardware.py" << 'PY'
import sys
open(sys.argv[1], "w").write(
    "    ('miyoo rk3566 355 v10*', 'miyoo-flip'),\n"
    '    "Anbernic RG353 M/V/P": {"device": "rg353m"},\n'
)
PY
cat > "$work/pugwash-fake" << EOF
#!/bin/sh
if [ ! -f "$work/saw-reboot" ]; then
	: > "$work/saw-reboot"
	: > .pugwash-reboot
	exit 0
fi
: > "$work/second-start"
exit 0
EOF
chmod 0755 "$work/pugwash-fake"
cat > "$work/prepare-count" << EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$work/prepare.log"
exec "$PREPARE" "\$@"
EOF
chmod 0755 "$work/prepare-count"
: > "$work/prepare.log"
ZLYME_PM_PREPARE=$work/prepare-count \
ZLYME_PM_PUGWASH=$work/pugwash-fake \
	"$LAUNCH"
test -f "$work/second-start"
test ! -f "$live/.pugwash-reboot"
test "$(wc -l < "$work/prepare.log")" -ge 2

# An explicit missing disk does not reset the other card.
mkdir -p "$sd2"
printf '%s\n' "$storage" "$sd2" > "$work/libraries"
"$ROOTBIN" set "$sd2"
rm -rf "$sd2"
if ZLYME_RESET_ROOT=$work \
	ZLYME_PM_STORAGE=$storage \
	ZLYME_PM_FLAG=$work/flag \
	ZLYME_LIBRARIES_FILE=$work/libraries \
	ZLYME_PM_ROOT_BIN=$ROOTBIN \
	ZLYME_CFG=$work/cfg \
	"$RESET" portmaster >"$work/out" 2>"$work/err"; then
	fail "missing disk was reset"
fi
grep -q 'not inserted' "$work/err"
test -f "$live/pugwash"

echo "portmaster prepare ok"
