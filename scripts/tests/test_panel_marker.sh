#!/bin/sh
# Compile the patched SDL marker functions and round-trip the file.
# The CRTC disable arguments are checked against the applied source.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "panel-marker: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

base=https://raw.githubusercontent.com/libsdl-org/SDL/release-2.32.10/src/video/kmsdrm
mkdir -p "$work/src/src/video/kmsdrm"
curl -fsSL "$base/SDL_kmsdrmopengles.c" -o "$work/src/src/video/kmsdrm/SDL_kmsdrmopengles.c"
curl -fsSL "$base/SDL_kmsdrmvideo.c" -o "$work/src/src/video/kmsdrm/SDL_kmsdrmvideo.c"
patch -d "$work/src" --fuzz=0 -p1 < "$ROOT/board/my355/patches/sdl2/0001-kmsdrm-honor-zlyme-hdmi-mode.patch"
patch -d "$work/src" --fuzz=0 -p1 < "$ROOT/board/my355/patches/sdl2/0002-kmsdrm-disable-panel-after-hdmi-scanout.patch"

python3 - "$work" << 'PY'
import pathlib, sys
work = pathlib.Path(sys.argv[1])
gl = (work / "src/src/video/kmsdrm/SDL_kmsdrmopengles.c").read_text()
vid = (work / "src/src/video/kmsdrm/SDL_kmsdrmvideo.c").read_text()

def extract(text, name):
    key = name + "("
    start = text.find(key)
    if start < 0:
        raise SystemExit(f"missing {name}")
    # include the static return type on the same declaration
    line = text.rfind("\n", 0, start) + 1
    brace = text.find("{", start)
    if brace < 0:
        raise SystemExit(f"no body {name}")
    depth = 0
    i = brace
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[line:i + 1]
        i += 1
    raise SystemExit(f"unclosed {name}")

names = [
    "KMSDRM_ZlymeMarkerPath",
    "KMSDRM_ZlymeMarkerOn",
    "KMSDRM_ZlymeWriteMarker",
    "KMSDRM_ZlymeRestorePanel",
    "KMSDRM_ZlymeNotePanel",
    "KMSDRM_ZlymePanelPath",
    "KMSDRM_ZlymePanelMarker",
]
parts = []
for n in names:
    src = gl if "Panel" not in n else vid
    if n.startswith("KMSDRM_ZlymePanel"):
        src = vid
    else:
        src = gl
    parts.append(extract(src, n))
# The disable request has to be the form Linux 7.2.10 drm_mode_setcrtc accepts:
# count_connectors > 0 without a mode and fb returns -EINVAL (drm_crtc.c).
disable = "KMSDRM_drmModeSetCrtc(fd, crtc->crtc_id, 0, 0, 0, NULL, 0, NULL)"
if disable not in gl:
    raise SystemExit("applied source does not disable with an empty connector list")
if "&conn->connector_id, 1, NULL" in gl:
    raise SystemExit("applied source still disables with a connector and no mode")
if "fprintf" in gl.split("KMSDRM_GLES_SwapWindow", 1)[0]:
    # upstream SwapWindow is after the marker helpers. The helpers must not fprintf a mode.
    head = gl.split("int KMSDRM_GLES_SwapWindow", 1)[0]
    if "fprintf" in head or "fscanf" in head:
        raise SystemExit("marker helpers still use fprintf or fscanf")
(work / "marker.c").write_text(r'''
#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
static int zlyme_panel_off;
#define SDL_strcmp strcmp
#define SDL_getenv getenv
#define SDL_Log(...) do { } while (0)
static int g_fail;
#define CHECK(cond) do { if (!(cond)) { fprintf(stderr, "fail %s\n", #cond); g_fail = 1; } } while (0)
''' + "\n".join(parts) + r'''
int main(void) {
    char dir[] = "/tmp/zlyme-marker-XXXXXX";
    char path[128];
    FILE *fp;
    if (!mkdtemp(dir)) return 1;
    snprintf(path, sizeof path, "%s/mark", dir);
    setenv("ZLYME_HDMI_PANEL_MARK", path, 1);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    CHECK(!KMSDRM_ZlymePanelMarker());
    KMSDRM_ZlymeWriteMarker();
    CHECK(KMSDRM_ZlymeMarkerOn());
    CHECK(KMSDRM_ZlymePanelMarker());
    KMSDRM_ZlymeRestorePanel(3);
    CHECK(KMSDRM_ZlymeMarkerOn());
    KMSDRM_ZlymeNotePanel(0);
    CHECK(KMSDRM_ZlymeMarkerOn());
    KMSDRM_ZlymeNotePanel(9);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp); fputs("", fp); fclose(fp);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp); fputs("panel-of", fp); fclose(fp);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp); fputs("panel-off", fp); fclose(fp);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp); fputs("panel-off\nextra\n", fp); fclose(fp);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp); fputs("panel-off\n", fp); fclose(fp);
    CHECK(KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp);
    fwrite("0123456789abcdef panel-off\n", 1, 26, fp); fclose(fp);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    fp = fopen(path, "w"); CHECK(fp); fputs("dsi 1 2 3\n", fp); fclose(fp);
    CHECK(!KMSDRM_ZlymeMarkerOn());
    KMSDRM_ZlymeWriteMarker();
    CHECK(KMSDRM_ZlymePanelMarker());
    unlink(path);
    rmdir(dir);
    return g_fail;
}
''')
PY

cc -std=c11 -Wall -Wextra -Wformat=2 -Werror=format -Werror -o "$work/marker" "$work/marker.c"
"$work/marker"
echo "panel marker ok"
