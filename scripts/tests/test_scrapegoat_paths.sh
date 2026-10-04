#!/bin/sh
# ZcrapeGoat path contract: every library, real ROM roots, no fixed ceilings.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
src=$ROOT/package/system/zcrapegoat/src/src
launch=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak/launch.sh

grep -q '/usr/lib/zlyme/zcrapegoat/zcrapegoat' "$launch"
grep -q 'SCRAPEGOAT_SYSTEMS_JSON=' "$launch"
if grep -q 'LOG_FILE=' "$launch"; then
	echo "launcher still builds its own log path" >&2
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

static void need(int cond, const char *msg) {
    if (!cond) {
        fprintf(stderr, "%s\n", msg);
        exit(1);
    }
}

static int has_suffix(zlyme_strlist *list, const char *suffix) {
    int i;
    for (i = 0; i < list->count; i++) {
        size_t n = strlen(list->item[i]);
        size_t m = strlen(suffix);
        if (n >= m && strcmp(list->item[i] + n - m, suffix) == 0)
            return 1;
    }
    return 0;
}

int main(void) {
    zlyme_strlist roots = {0};
    zlyme_strlist systems = {0};
    zlyme_strlist dirs = {0};
    char buf[PATH_MAX];
    char key[PATH_MAX];
    char art[PATH_MAX];
    const char *sd1 = getenv("SG_SD1");
    const char *sd2 = getenv("SG_SD2");
    const char *usb = getenv("SG_USB");

    need(zlyme_library_roots(&roots) == 0, "roots");
    need(roots.count == 12, "twelve libraries, old ceiling was 8");
    need(strcmp(roots.item[0], sd1) == 0, "trailing slash normalized");
    need(strcmp(roots.item[1], sd2) == 0, "sd2");
    need(strcmp(roots.item[2], usb) == 0, "usb");
    zlyme_strlist_free(&roots);

    need(zlyme_system_dirs(&systems) == 0, "systems");
    need(systems.count == 68, "more than 64 systems");
    need(has_suffix(&systems, "/Game Boy (GB)"), "gb");
    need(has_suffix(&systems, "/roms/SNES") || has_suffix(&systems, "/SNES"), "snes on lowercase roms");
    {
        int i, gb = 0;
        const char *gb_path = NULL;
        for (i = 0; i < systems.count; i++) {
            const char *base = strrchr(systems.item[i], '/') + 1;
            if (strcmp(base, "Game Boy (GB)") == 0) {
                gb++;
                gb_path = systems.item[i];
            }
        }
        need(gb == 1, "one logical gb row");
        /* Same folder name on a later library is not a second row.
         * The listed path is the earlier library, wherever it sits. */
        need(gb_path && strncmp(gb_path, sd1, strlen(sd1)) == 0,
             "duplicate system keeps the earlier library");
    }
    zlyme_strlist_free(&systems);

    snprintf(buf, sizeof(buf), "%s/Roms/Game Boy (GB)", sd1);
    need(zlyme_rom_dirs(buf, &dirs) == 0, "rom dirs");
    need(dirs.count == 2, "gb on storage and sd2");
    need(strstr(dirs.item[0], sd1) != NULL, "art library 1");
    need(strstr(dirs.item[1], sd2) != NULL, "art library 2");
    zlyme_strlist_free(&dirs);

    snprintf(buf, sizeof(buf), "%s/roms/SNES/Super.sfc", sd2);
    zlyme_artwork_path(buf, "Super", art, sizeof(art));
    snprintf(key, sizeof(key), "%s/roms/SNES/.media/Super.png", sd2);
    need(strcmp(art, key) == 0, "sd2 artwork");

    snprintf(buf, sizeof(buf), "%s/Roms/Game Boy (GB)/Tetris.gb", sd1);
    zlyme_artwork_path(buf, "Tetris", art, sizeof(art));
    snprintf(key, sizeof(key), "%s/Roms/Game Boy (GB)/.media/Tetris.png", sd1);
    need(strcmp(art, key) == 0, "sd1 artwork");

    zlyme_cheats_root(buf, sizeof(buf));
    need(strcmp(buf, "/storage/Cheats") == 0, "cheats");
    zlyme_state_root(buf, sizeof(buf));
    need(strcmp(buf, "/storage/.config/ZcrapeGoat") == 0, "state default");
    need(strstr(buf, "ScrapeGoat") == NULL || strstr(buf, "ZcrapeGoat") != NULL, "name");
    need(strstr(buf, ".userdata") == NULL, "not userdata");

    snprintf(buf, sizeof(buf), "%s/roms/SNES", sd2);
    need(zlyme_folder_key(buf, key, sizeof(key)) == 1, "lower roms key");
    need(strcmp(key, "SNES") == 0, "key text");

    snprintf(buf, sizeof(buf), "%s/Roms/.Hidden (HID)", sd1);
    need(zlyme_system_dirs(&systems) == 0, "rescan");
    need(has_suffix(&systems, "/.Hidden (HID)"), "dot dir is enumerable");
    zlyme_strlist_free(&systems);

    zlyme_collision_label(key, sizeof(key), "Tetris",
                          getenv("SG_DUP"));
    need(strstr(key, sd2) != NULL, "collision label");
    return 0;
}
EOF

sd1=$work/storage
sd2=$work/sd2
usb=$work/usb
mkdir -p "$sd1/Roms/Game Boy (GB)" "$sd2/roms/Game Boy (GB)" "$sd2/roms/SNES" \
	"$usb/ROMS/Pico" "$sd1/Roms/.Hidden (HID)"
printf 'a' > "$sd1/Roms/Game Boy (GB)/Tetris.gb"
printf 'b' > "$sd2/roms/Game Boy (GB)/Tetris.gb"
printf 'c' > "$sd2/roms/SNES/Super.sfc"
i=0
while [ "$i" -lt 64 ]; do
	mkdir -p "$sd1/Roms/Sys$i (S$i)"
	i=$((i + 1))
done
{
	printf '%s/\n' "$sd1"
	printf '%s\n' "$sd2" "$usb"
	printf '   \n'
	printf '%s\n' "$sd2"
	n=0
	while [ "$n" -lt 9 ]; do
		printf '%s/extra%s\n' "$work" "$n"
		mkdir -p "$work/extra$n/Roms"
		n=$((n + 1))
	done
} > "$work/libraries"

ZLYME_LIBRARIES_FILE=$work/libraries \
SG_SD1=$sd1 SG_SD2=$sd2 SG_USB=$usb \
SG_DUP="$sd2/roms/Game Boy (GB)/Tetris.gb" \
	"$cc"
echo "zcrapegoat paths ok"
