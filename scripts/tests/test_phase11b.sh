#!/bin/sh
# Phase 11B host contract: OpenBOR runtime dirs, MKXP-Z one wrapper
# directory, and Wine 11.6 WoW64 with an exFAT prefix. Nothing here is
# installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() {
	echo "phase11b: $*" >&2
	exit 1
}

OPENBOR_LAUNCH=$ROOT/package/system/nextui/paks/Emus/OPENBOR.pak/launch.sh
OPENBOR_PATCH=$ROOT/package/emulators/openbor/0003-runtime-directories.patch
CLEANUP=$ROOT/package/system/nextui/zlyme/zlyme-game-cleanup.sh
MKXP_MK=$ROOT/package/emulators/libretro-mkxp-z/libretro-mkxp-z.mk
MKXP_PATCH=$ROOT/package/emulators/libretro-mkxp-z/0001-one-wrapper-archive-root.patch
ROM_EXTS=$ROOT/package/system/nextui/rom-exts.txt
WINE_MK=$ROOT/package/emulators/wine-amd64/wine-amd64.mk
WINE_HASH=$ROOT/package/emulators/wine-amd64/wine-amd64.hash
WINE_PREFIX=$ROOT/package/emulators/wine-amd64/zlyme-wine-prefix
WINE_LAUNCH=$ROOT/package/system/nextui/paks/Emus/WINE.pak/launch.sh
SESSION=$ROOT/package/system/nextui/nextui-session
POST=$ROOT/board/my355/post-update.sh
BOX64=$ROOT/package/system/box64/box64.mk
README=$ROOT/README.md

for f in "$OPENBOR_LAUNCH" "$OPENBOR_PATCH" "$CLEANUP" "$MKXP_MK" "$MKXP_PATCH" \
	"$ROM_EXTS" "$WINE_MK" "$WINE_HASH" "$WINE_PREFIX" "$WINE_LAUNCH" \
	"$SESSION" "$POST" "$BOX64" "$README"; do
	[ -f "$f" ] || fail "missing $f"
done

# OpenBOR: the ROM directory is an argument, not the working directory.
grep -q 'cd "$state"' "$OPENBOR_LAUNCH" || fail "openbor cwd"
grep -q 'OpenBOR "$ROM"' "$OPENBOR_LAUNCH" || fail "openbor rom argument"
if grep -q 'dirname "$ROM"' "$OPENBOR_LAUNCH"; then
	fail "openbor still derives a ROM directory"
fi
for var in OPENBOR_PAKS_DIR OPENBOR_SAVES_DIR OPENBOR_LOGS_DIR OPENBOR_SCREENSHOTS_DIR; do
	grep -q "$var" "$OPENBOR_LAUNCH" || fail "launcher missing $var"
	grep -q "$var" "$OPENBOR_PATCH" || fail "patch missing $var"
done
grep -q 'OPENBOR_SAVES_DIR="$SAVES_PATH/$EMU_TAG"' "$OPENBOR_LAUNCH" || fail "saves tag"
grep -q '/tmp/zlyme-openbor/Logs' "$OPENBOR_LAUNCH" || fail "transient openbor logs"
grep -q 'LOGS_PATH' "$OPENBOR_LAUNCH" || fail "persistent openbor logs"
if grep -E '^-char (paksDir|savesDir|logsDir|screenShotsDir)' "$OPENBOR_PATCH" >/dev/null; then
	fail "patch changes upstream directory defaults"
fi
grep -q 'strcpy(buf, "./Paks/")' "$OPENBOR_PATCH" || fail "non-SDL paks default"
grep -q 'getenv(envname)' "$OPENBOR_PATCH" || fail "override getenv"
grep -F "val[0] == '\\0'" "$OPENBOR_PATCH" >/dev/null || fail "empty override"
grep -q 'MAX_LABEL_LEN - 1' "$OPENBOR_PATCH" || fail "override length cap"
grep -q 'copy_sdl_root_path' "$OPENBOR_PATCH" || fail "saves path helper"
grep -q 'bor_log_path' "$OPENBOR_PATCH" || fail "log path helper"
if grep -q '/storage' "$OPENBOR_PATCH"; then
	fail "openbor patch hardcodes a Zlyme path"
fi
if grep -E 'OPENBOR|OpenBOR' "$CLEANUP" | grep -q 'find '; then
	fail "cleanup still scans OpenBOR ROM trees"
fi
if grep -E 'migrate|cp |Roms/' "$OPENBOR_LAUNCH" | grep -q .; then
	fail "openbor launcher has migration or a ROM copy"
fi

# MKXP-Z: pin, one wrapper directory, advertised extensions, no migration.
grep -q 'LIBRETRO_MKXP_Z_VERSION = 650cb0888a07d0b5044e131160ddfa53feaf595b' "$MKXP_MK" || fail "mkxp pin"
grep -q 'PHYSFS_setRoot' "$MKXP_PATCH" || fail "setRoot"
grep -q 'Game.ini' "$MKXP_PATCH" || fail "Game.ini marker"
grep -q 'Data/Scripts.rxdata' "$MKXP_PATCH" || fail "rxdata marker"
grep -q 'counted.dirs == 1' "$MKXP_PATCH" || fail "one directory"
grep -q 'save_path_subdir.append("/Saves/")' "$MKXP_PATCH" || fail "save subdir"
if grep -E '^\+.*append\("/mkxp-z/Saves/"\)' "$MKXP_PATCH" >/dev/null; then
	fail "duplicated mkxp-z save component remains"
fi
# The enumerator counts one level. It does not walk again.
awk '
	/static PHYSFS_EnumerateCallbackResult count_game_root/ { in_fn = 1 }
	in_fn { print }
	in_fn && /static bool archive_game_path/ { exit }
' "$MKXP_PATCH" | grep -q 'PHYSFS_enumerate' && fail "wrapper walk is recursive"
grep -q 'MKXPZ: ini json rxproj rvproj rvproj2 mkxpz zip 7z' "$ROM_EXTS" || fail "rom-exts"
if grep '^MKXPZ:' "$ROM_EXTS" | grep -E '(^| )mkxp( |$)' >/dev/null; then
	fail "rom-exts still lists .mkxp"
fi
if grep 'RPG Maker XP / VX / Ace' "$README" | grep -E '\.mkxp([^z]|$)' >/dev/null; then
	fail "README still lists .mkxp"
fi
for ext in '.ini' '.json' '.rxproj' '.rvproj' '.rvproj2' '.mkxpz' '.zip' '.7z'; do
	grep 'RPG Maker XP / VX / Ace' "$README" | grep -q "$ext" || fail "README missing $ext"
done
if grep -E 'migrate|legacy' "$MKXP_PATCH" >/dev/null; then
	fail "mkxp patch has migration"
fi

python3 - "$ROOT" << 'PY'
import io, sys, zipfile
from pathlib import Path

def classify(names):
    norm = []
    for raw in names:
        name = raw.replace("\\", "/").lstrip("/")
        if not name or name.endswith("/"):
            name = name.rstrip("/")
            if name:
                norm.append((name, True))
            continue
        norm.append((name, False))
    def marker(prefix):
        ini = f"{prefix}Game.ini" if prefix else "Game.ini"
        data = f"{prefix}Data/Scripts.rxdata" if prefix else "Data/Scripts.rxdata"
        files = {n for n, _ in norm}
        return ini in files or data in files
    if marker(""):
        return "root", None
    dirs = []
    for name, is_dir in norm:
        top = name.split("/", 1)[0]
        if top.startswith(".") or not top:
            continue
        if is_dir or "/" in name:
            if top not in dirs:
                dirs.append(top)
    if len(dirs) != 1:
        return "fail", None
    only = dirs[0]
    if marker(only + "/"):
        return "unwrap", only
    return "fail", None

cases = {
    "root": ["Game.ini", "Data/Scripts.rxdata"],
    "unwrap": ["My Game/Game.ini", "My Game/Data/Scripts.rxdata"],
    "two": ["A/Game.ini", "B/Game.ini"],
    "nested": ["A/B/Game.ini"],
    "readme": ["readme.txt", "Only/Game.ini"],
    "dot": [".secret/Game.ini"],
    "empty": [],
    "plain": ["Only/readme.txt"],
}
expect = {
    "root": ("root", None),
    "unwrap": ("unwrap", "My Game"),
    "two": ("fail", None),
    "nested": ("fail", None),
    "readme": ("unwrap", "Only"),
    "dot": ("fail", None),
    "empty": ("fail", None),
    "plain": ("fail", None),
}
work = Path(sys.argv[1])
# The second argv is the repo; fixtures stay in memory.
for key, names in cases.items():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name in names:
            zf.writestr(name, b"x")
    with zipfile.ZipFile(io.BytesIO(buf.getvalue())) as zf:
        got = classify(zf.namelist())
    if got != expect[key]:
        raise SystemExit(f"layout {key}: {got} != {expect[key]}")
print("mkxp layouts ok")
PY

# Wine 11.6 amd64-wow64, Box64 unchanged, exFAT prefix, exact ext4 delete.
grep -q 'WINE_AMD64_VERSION = 11.6' "$WINE_MK" || fail "wine version"
grep -q 'rm -rf $(TARGET_DIR)/usr/lib/wine-amd64' "$WINE_MK" || fail "wine install merges"
grep -q 'wine-$(WINE_AMD64_VERSION)-amd64-wow64.tar.xz' "$WINE_MK" || fail "wine asset"
grep -q '045549657b513c2fb191734b0434c81000b36ba4d482d1688bf99f80a8ee07a5' "$WINE_HASH" || fail "wine hash"
grep -q 'wine-11.6-amd64-wow64.tar.xz' "$WINE_HASH" || fail "wine hash name"
if grep -q e2fsprogs "$WINE_MK"; then
	fail "wine still depends on e2fsprogs"
fi
grep -q 'BOX64_VERSION = 2f130fab1d6e1a4ee8a71dc60cfdfcc839ad192a' "$BOX64" || fail "box64 pin"
grep -q 'BOX32=OFF' "$BOX64" || fail "box32"
grep -q 'TMPFS_SIZE=1024k' "$WINE_PREFIX" || fail "tmpfs size"
grep -q '/dosdevices' "$WINE_PREFIX" || fail "dosdevices"
grep -q 'ln -sfn ../drive_c' "$WINE_PREFIX" || fail "c: link"
grep -q 'ln -sfn / ' "$WINE_PREFIX" || fail "z: link"
grep -q 'prepare) prepare_cmd' "$WINE_PREFIX" || fail "prepare"
grep -q 'cleanup) cleanup_cmd' "$WINE_PREFIX" || fail "cleanup"
grep -q 'owned_tmpfs' "$WINE_PREFIX" || fail "ownership check"
grep -q 'WINEPREFIX=$prefix' "$WINE_PREFIX" || fail "wineserver prefix"
grep -q 'rm -rf "$STATE"' "$WINE_PREFIX" || fail "run state"
if grep -E 'losetup|mkfs\.ext4|e2fsck|SIZE_MIB|wine-prefix\.ext4' "$WINE_PREFIX" >/dev/null; then
	fail "prefix helper still has the ext4 image"
fi
if grep -E 'rm -rf "\$prefix"|rm -rf "\$(prefix_dir)"' "$WINE_PREFIX" >/dev/null; then
	fail "cleanup deletes the prefix"
fi
grep -q 'zlyme-wine-prefix prepare' "$WINE_LAUNCH" || fail "launcher prepare"
grep -q 'zlyme-weston-run wine' "$WINE_LAUNCH" || fail "weston"
grep -q 'zlyme-wine-prefix cleanup' "$SESSION" || fail "session cleanup"
if grep -E 'losetup|mkfs\.ext4|e2fsck' "$WINE_LAUNCH" "$SESSION" >/dev/null; then
	fail "launcher or session still loops an ext4 prefix"
fi
grep -q 'legacy="$root/.config/nextui/my355/wine-prefix.ext4"' "$POST" || fail "legacy path"
grep -q '\[ -f "$legacy" \]' "$POST" || fail "legacy file test"
grep -q 'rm -f "$legacy"' "$POST" || fail "legacy rm"
if grep -E 'wine-prefix\*|\*\.ext4|find .*wine' "$POST" >/dev/null; then
	fail "post-update wine cleanup is not exact"
fi
if grep -E -i 'gl4es|fluidsynth|soundfont|dxvk|vkd3d|gamepad-to-mouse' \
	"$WINE_MK" "$WINE_PREFIX" "$WINE_LAUNCH" "$ROOT/package/emulators/wine-amd64/wine.sh" >/dev/null; then
	fail "first Wine pass includes a compatibility layer"
fi
grep -q 'CONFIG_NTSYNC=y' "$ROOT/board/my355/linux/linux.config" || fail "ntsync audit"
if grep -R --include='test_phase11b.sh' -l test_phase11b "$ROOT/package" "$ROOT/board" >/dev/null 2>&1; then
	fail "phase 11b test is packaged"
fi

thanks=$(awk '/^## Thanks$/{f=1; next} /^## License$/{f=0} f' "$README")
printf '%s\n' "$thanks" | grep -q 'lazydog' || fail "lazydog credit"
printf '%s\n' "$thanks" | grep -q 'Wine' || fail "lazydog credit is not the Wine note"

# OpenBOR SDL helpers format into a bounded buffer. The non-SDL branch
# still has the upstream strcpy macros.
python3 - "$OPENBOR_PATCH" << 'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
start = text.find("static void sdl_format_path")
end = text.find("#endif", text.find("static void copy_sdl_paks_path"))
body = text[start:end]
if "snprintf" not in body or "strcpy" in body or "strcat" in body:
    raise SystemExit("openbor SDL path helpers are not bounded")
if "n + 1 > limit" not in text or "borExit(1)" not in text:
    raise SystemExit("openbor overflow does not fail closed")
print("openbor paths bounded")
PY

MKXP_MK=$ROOT/package/emulators/libretro-mkxp-z/libretro-mkxp-z.mk
MKXP_LIST=$ROOT/package/emulators/libretro-mkxp-z/mkxp-offline.list
MKXP_HASH=$ROOT/package/emulators/libretro-mkxp-z/libretro-mkxp-z.hash
MKXP_STAGE1=$ROOT/package/emulators/libretro-mkxp-z/0002-offline-deterministic-stage1.patch
for f in "$MKXP_LIST" "$MKXP_HASH" "$MKXP_STAGE1"; do
	[ -f "$f" ] || fail "missing $f"
done
if grep -n wget "$MKXP_MK" >/dev/null; then
	fail "mkxp recipe still runs wget"
fi
# Configure and build commands must not fetch. Download URLs stay in
# EXTRA_DOWNLOADS, which Buildroot fetches before the build.
awk '
	/^define / { grab = ($2 ~ /CONFIGURE_CMDS|BUILD_CMDS|INSTALL_TARGET_CMDS|STAGE_WRAP/) }
	grab { print }
	/^endef$/ { grab = 0 }
' "$MKXP_MK" | grep -E 'wget|curl |git clone' && fail "mkxp build commands fetch"
grep -q -- '--wrap-mode=nodownload' "$MKXP_MK" || fail "meson can still download wraps"
if grep -E '^\+' "$MKXP_STAGE1" | grep -q '/dev/urandom'; then
	fail "stage1 patch still reads /dev/urandom"
fi
grep -q sha256sum "$MKXP_STAGE1" || fail "stage1 markers are not a digest"
# Every staged archive is hash-checked. A missing line fails the build.
while read -r role name archive; do
	case "$role" in
		\#*|"") continue ;;
	esac
	grep -q "  $archive\$" "$MKXP_HASH" || fail "no hash for $archive"
done < "$MKXP_LIST"
grep -q '  wasi-sdk-30.0-x86_64-linux.tar.gz$' "$MKXP_HASH" || fail "no wasi hash"
grep -q '  binaryen-version_123-x86_64-linux.tar.gz$' "$MKXP_HASH" || fail "no binaryen hash"

echo "phase11b: ok"
