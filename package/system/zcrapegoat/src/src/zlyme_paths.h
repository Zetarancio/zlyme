#ifndef ZLYME_PATHS_H
#define ZLYME_PATHS_H

#include <limits.h>
#include <stddef.h>

/* Zlyme library and path contract for ZcrapeGoat.
 * Libraries come from ZLYME_LIBRARIES_FILE or /run/zlyme/libraries.
 * ROM roots follow NextUI: Roms, then roms, then ROMS.
 * Private state is /storage/.config/ZcrapeGoat.
 * Installed cheats stay at /storage/Cheats.
 */

typedef struct {
	char **item;
	int count;
} zlyme_strlist;

void zlyme_strlist_free(zlyme_strlist *list);

int zlyme_library_roots(zlyme_strlist *out);
const char *zlyme_library_of(const char *path);

int zlyme_library_roms_dir(const char *library, char *buf, size_t buflen);

void zlyme_state_root(char *buf, size_t buflen);
void zlyme_cheats_root(char *buf, size_t buflen);
void zlyme_settings_path(char *buf, size_t buflen);
void zlyme_overrides_path(char *buf, size_t buflen);
void zlyme_cheat_repo_path(char *buf, size_t buflen);
void zlyme_daemon_dir(char *buf, size_t buflen);

int zlyme_folder_key(const char *console_path, char *buf, size_t buflen);
void zlyme_artwork_path(const char *rom_path, const char *display_name,
			char *buf, size_t buflen);
int zlyme_system_dirs(zlyme_strlist *out);
int zlyme_rom_dirs(const char *console_path, zlyme_strlist *out);

void zlyme_collision_label(char *label, size_t label_len,
			   const char *display, const char *rom_path);

#endif
