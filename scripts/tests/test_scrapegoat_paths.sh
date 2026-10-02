#!/bin/sh
# ScrapeGoat sees every Zlyme library and writes state and cheats
# to the OS card, not beside a second copy of the ROM.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
src=$ROOT/package/system/zcrapegoat/src/src
launch=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/launch.sh

grep -q '/usr/lib/zlyme/zcrapegoat/zcrapegoat' "$launch"
grep -q '/etc/ssl/certs/ca-certificates.crt' "$launch"
if grep -q '\.userdata/shared/ScrapeGoat' "$launch"; then
	echo "scrapegoat launcher still uses .userdata state" >&2
	exit 1
fi
if [ -e "$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/zcrapegoat" ]; then
	echo "pak still ships a second scrapegoat binary" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc=$work/paths
gcc -std=gnu11 -Wall -Wextra -Wno-format-truncation \
	-I "$src" -o "$cc" "$src/zlyme_paths.c" -x c - << 'EOF'
#include "zlyme_paths.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void need(int cond, const char *msg) {
    if (!cond) {
        fprintf(stderr, "%s\n", msg);
        exit(1);
    }
}

int main(void) {
    char roots[8][PATH_MAX];
    char dirs[8][PATH_MAX];
    char buf[PATH_MAX];
    char key[PATH_MAX];
    int n, i;
    const char *base = getenv("SG_BASE");

    n = zlyme_library_roots(roots, 8);
    need(n == 2, "library count");
    need(strcmp(roots[0], getenv("SG_SD1")) == 0, "sd1");
    need(strcmp(roots[1], getenv("SG_SD2")) == 0, "sd2");

    n = zlyme_system_dirs(dirs, 8);
    need(n == 2, "system count");
    need(strstr(dirs[0], "Game Boy (GB)") != NULL, "gb listed");
    need(strstr(dirs[1], "SNES") != NULL || strstr(dirs[0], "SNES") != NULL, "snes listed");
    for (i = 0; i < n; i++) {
        if (strstr(dirs[i], "Game Boy (GB)"))
            need(strncmp(dirs[i], getenv("SG_SD1"), strlen(getenv("SG_SD1"))) == 0,
                 "gb console path stays on the first library");
    }

    snprintf(buf, sizeof(buf), "%s/Roms/Game Boy (GB)", getenv("SG_SD1"));
    n = zlyme_rom_dirs(buf, dirs, 8);
    need(n == 2, "gb rom dirs");
    need(strstr(dirs[0], getenv("SG_SD1")) != NULL, "gb sd1");
    need(strstr(dirs[1], getenv("SG_SD2")) != NULL, "gb sd2");

    snprintf(buf, sizeof(buf), "%s/Roms/SNES", getenv("SG_SD2"));
    n = zlyme_rom_dirs(buf, dirs, 8);
    need(n == 1, "snes only sd2");
    need(strstr(dirs[0], getenv("SG_SD2")) != NULL, "snes path");

    zlyme_artwork_path("/mnt/sd2/Roms/Game Boy (GB)/Tetris.gb", "Tetris", buf, sizeof(buf));
    need(strcmp(buf, "/mnt/sd2/Roms/Game Boy (GB)/.media/Tetris.png") == 0, "sd2 art");
    zlyme_artwork_path("/storage/Roms/Game Boy (GB)/Tetris.gb", "Tetris", buf, sizeof(buf));
    need(strcmp(buf, "/storage/Roms/Game Boy (GB)/.media/Tetris.png") == 0, "sd1 art");

    zlyme_cheats_root(buf, sizeof(buf));
    need(strcmp(buf, "/storage/Cheats") == 0, "cheats");
    zlyme_state_root(buf, sizeof(buf));
    need(strcmp(buf, getenv("SG_STATE")) == 0, "state");
    zlyme_settings_path(buf, sizeof(buf));
    need(strstr(buf, "/.userdata/") == NULL, "settings not userdata");

    snprintf(buf, sizeof(buf), "%s/Roms/Game Boy (GB)", getenv("SG_SD2"));
    need(zlyme_folder_key(buf, key, sizeof(key)) == 1, "key");
    need(strcmp(key, "Game Boy (GB)") == 0, "same folder key");

    snprintf(buf, sizeof(buf), "%s/Roms/Game Boy (GB)/Tetris.gb", getenv("SG_SD2"));
    {
        char label[PATH_MAX];
        label[0] = '\0';
        zlyme_collision_label(label, sizeof(label), "Tetris", buf);
        need(strstr(label, "Tetris") != NULL && strstr(label, getenv("SG_SD2")) != NULL, "label");
    }

    snprintf(buf, sizeof(buf), "%s/.userdata/shared/ScrapeGoat", base);
    need(access(buf, F_OK) != 0, "did not create userdata state");
    snprintf(buf, sizeof(buf), "%s/.userdata/shared/ZcrapeGoat", base);
    need(access(buf, F_OK) != 0, "did not create zcrapegoat userdata");
    return 0;
}
EOF

sd1=$work/sd1
sd2=$work/sd2
mkdir -p "$sd1/Roms/Game Boy (GB)" "$sd2/Roms/Game Boy (GB)" "$sd2/Roms/SNES"
printf 'a' > "$sd1/Roms/Game Boy (GB)/Tetris.gb"
printf 'b' > "$sd2/Roms/Game Boy (GB)/Tetris.gb"
printf 'c' > "$sd2/Roms/SNES/Super.sfc"
mkdir -p "$work/legacy"
printf '{"kept":true}\n' > "$work/legacy/settings.json"
printf '%s\n%s\n' "$sd1" "$sd2" > "$work/libraries"

SG_BASE=$work \
SG_SD1=$sd1 SG_SD2=$sd2 \
SG_STATE=$work/state SG_LEGACY=$work/legacy \
ZLYME_LIBRARIES_FILE=$work/libraries \
ZLYME_ZCRAPEGOAT_STATE=$work/state \
ZLYME_CHEATS_PATH=/storage/Cheats \
"$cc"

echo "scrapegoat paths ok"
