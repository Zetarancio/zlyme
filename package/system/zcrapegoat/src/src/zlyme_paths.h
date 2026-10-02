#ifndef ZLYME_PATHS_H
#define ZLYME_PATHS_H

#include <limits.h>
#include <stddef.h>

/* Zlyme library and path contract for ScrapeGoat.
 * Libraries come from ZLYME_LIBRARIES_FILE or /run/zlyme/libraries.
 * Private state is /storage/.config/ScrapeGoat.
 * Installed cheats stay at /storage/Cheats.
 */

int zlyme_library_roots(char roots[][PATH_MAX], int max);
const char *zlyme_library_of(const char *path);

void zlyme_state_root(char *buf, size_t buflen);
void zlyme_cheats_root(char *buf, size_t buflen);
void zlyme_settings_path(char *buf, size_t buflen);
void zlyme_overrides_path(char *buf, size_t buflen);
void zlyme_cheat_repo_path(char *buf, size_t buflen);
void zlyme_daemon_dir(char *buf, size_t buflen);

int zlyme_folder_key(const char *console_path, char *buf, size_t buflen);
void zlyme_artwork_path(const char *rom_path, const char *display_name,
			char *buf, size_t buflen);
int zlyme_system_dirs(char paths[][PATH_MAX], int max);
int zlyme_rom_dirs(const char *console_path, char dirs[][PATH_MAX], int max);

void zlyme_collision_label(char *label, size_t label_len,
			   const char *display, const char *rom_path);

#endif
