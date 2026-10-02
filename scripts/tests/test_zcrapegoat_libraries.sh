#!/bin/sh
# Logical system visibility and ROM union across Zlyme libraries.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
src=$ROOT/package/system/zcrapegoat/src
catalog=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/resources/systems.json

for tag in GB GBC GBA FC SFC MD PS N64 NDS PSP; do
	grep -q "\"$tag\":" "$catalog"
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gcc -std=gnu11 -Wall -Wextra -Wno-format-truncation -Wno-unused-function \
	-I "$src/src" -I "$src/third_party/cJSON" -I "$src/third_party/md5" \
	-I "$src/third_party/miniz" \
	-o "$work/scan" \
	"$src/src/device.c" "$src/src/zlyme_paths.c" \
	"$src/third_party/cJSON/cJSON.c" "$src/third_party/md5/md5.c" \
	"$src/third_party/miniz/miniz.c" "$src/third_party/miniz/miniz_tdef.c" \
	"$src/third_party/miniz/miniz_tinfl.c" "$src/third_party/miniz/miniz_zip.c" \
	-x c - << 'EOF'
#include "device.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void die(const char *msg) {
    fprintf(stderr, "%s\n", msg);
    exit(1);
}

static int system_count(bool show_hidden, const char *tag) {
    console_dir *consoles = NULL;
    int n = scan_console_dirs(show_hidden, &consoles);
    int i, found = 0;
    if (n < 0)
        die("scan_console_dirs failed");
    for (i = 0; i < n; i++) {
        if (strcmp(consoles[i].tag, tag) == 0)
            found++;
    }
    free(consoles);
    return found;
}

static void dump_roms(const char *tag) {
    console_dir *consoles = NULL;
    int n = scan_console_dirs(false, &consoles);
    int i;
    if (n < 0)
        die("scan_console_dirs failed");
    for (i = 0; i < n; i++) {
        rom_file *roms = NULL;
        int r, count;
        if (strcmp(consoles[i].tag, tag) != 0)
            continue;
        count = scan_roms(consoles[i].path, false, &roms);
        if (count < 0)
            die("scan_roms failed");
        printf("system %s\n", consoles[i].tag);
        for (r = 0; r < count; r++)
            printf("rom %s | %s\n", roms[r].path, roms[r].label);
        free(roms);
    }
    free(consoles);
}

int main(int argc, char **argv) {
    if (argc < 2)
        die("mode");
    if (strcmp(argv[1], "count") == 0) {
        bool hidden = argc > 3 && strcmp(argv[3], "hidden") == 0;
        printf("%d\n", system_count(hidden, argv[2]));
        return 0;
    }
    if (strcmp(argv[1], "roms") == 0) {
        dump_roms(argv[2]);
        return 0;
    }
    if (strcmp(argv[1], "manual") == 0) {
        app_settings settings = {0};
        app_settings loaded;
        snprintf(settings.manual_download_dir,
                 sizeof(settings.manual_download_dir), "%s", argv[2]);
        if (save_settings(&settings) != 0)
            die("save_settings failed");
        loaded = load_settings();
        if (strcmp(loaded.manual_download_dir, argv[2]) != 0)
            die("manual directory did not persist");
        free_settings(&loaded);
        printf("manual ok\n");
        return 0;
    }
    die("unknown mode");
}
EOF

storage=$work/storage
sd2=$work/sd2
mkdir -p "$storage/Roms/Game Boy Color (GBC)"
mkdir -p "$sd2/Roms/Game Boy Color (GBC)"
printf 'x' > "$sd2/Roms/Game Boy Color (GBC)/Pokemon.gbc"
printf '%s\n%s\n' "$storage" "$sd2" > "$work/libraries"
export ZLYME_LIBRARIES_FILE=$work/libraries
export ZLYME_ZCRAPEGOAT_STATE=$work/state

n=$("$work/scan" count GBC)
test "$n" = 1
roms=$("$work/scan" roms GBC)
printf '%s\n' "$roms" | grep -q 'system GBC'
printf '%s\n' "$roms" | grep -q "$sd2/Roms/Game Boy Color (GBC)/Pokemon.gbc"

mkdir -p "$storage/Roms/Nintendo Entertainment System (FC)"
printf 'x' > "$storage/Roms/Nintendo Entertainment System (FC)/Mario.nes"
mkdir -p "$sd2/Roms/Nintendo Entertainment System (FC)"
n=$("$work/scan" count FC)
test "$n" = 1
roms=$("$work/scan" roms FC)
printf '%s\n' "$roms" | grep -q "$storage/Roms/Nintendo Entertainment System (FC)/Mario.nes"

printf 'x' > "$storage/Roms/Game Boy Color (GBC)/Link.gbc"
printf 'x' > "$sd2/Roms/Nintendo Entertainment System (FC)/Zelda.nes"
roms=$("$work/scan" roms GBC)
printf '%s\n' "$roms" | grep -q 'Pokemon.gbc'
printf '%s\n' "$roms" | grep -q 'Link.gbc'
roms=$("$work/scan" roms FC)
printf '%s\n' "$roms" | grep -q 'Mario.nes'
printf '%s\n' "$roms" | grep -q 'Zelda.nes'

rm -rf "$storage/Roms/Game Boy Color (GBC)"
n=$("$work/scan" count GBC)
test "$n" = 1
roms=$("$work/scan" roms GBC)
printf '%s\n' "$roms" | grep -q 'Pokemon.gbc'

mkdir -p "$sd2/Roms/Mystery Box (ZZZ)"
printf 'x' > "$sd2/Roms/Mystery Box (ZZZ)/quest.bin"
n=$("$work/scan" count ZZZ)
test "$n" = 1

mkdir -p "$storage/Roms/Game Boy (GB)" "$sd2/Roms/Game Boy (GB)"
printf 'x' > "$storage/Roms/Game Boy (GB)/Tetris.gb"
printf 'x' > "$sd2/Roms/Game Boy (GB)/Tetris.gb"
n=$("$work/scan" count GB)
test "$n" = 1
roms=$("$work/scan" roms GB)
test "$(printf '%s\n' "$roms" | grep -c 'Tetris.gb')" = 2
printf '%s\n' "$roms" | grep -q "$storage)"
printf '%s\n' "$roms" | grep -q "$sd2)"

mkdir -p "$storage/Roms/Empty Handheld (EH)" "$sd2/Roms/Empty Handheld (EH)"
n=$("$work/scan" count EH)
test "$n" = 0
n=$("$work/scan" count EH hidden)
test "$n" = 1

"$work/scan" manual "$work/manuals" >/dev/null
echo "zcrapegoat library scan ok"
