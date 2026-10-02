#include "zlyme_paths.h"

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic ignored "-Wformat-truncation"
#endif

static const char *rom_names[] = {"Roms", "roms", "ROMS"};

void zlyme_strlist_free(zlyme_strlist *list)
{
	int i;

	if (!list)
		return;
	for (i = 0; i < list->count; i++)
		free(list->item[i]);
	free(list->item);
	list->item = NULL;
	list->count = 0;
}

static int strlist_add(zlyme_strlist *list, const char *value)
{
	char **next;
	int i;

	if (!value || !value[0])
		return 0;
	for (i = 0; i < list->count; i++) {
		if (strcmp(list->item[i], value) == 0)
			return 0;
	}
	next = realloc(list->item, (size_t)(list->count + 1) * sizeof(*next));
	if (!next)
		return -1;
	list->item = next;
	list->item[list->count] = strdup(value);
	if (!list->item[list->count])
		return -1;
	list->count++;
	return 0;
}

static void trim_inplace(char *s)
{
	char *end;
	size_t n;

	while (*s && isspace((unsigned char)*s))
		memmove(s, s + 1, strlen(s));
	n = strlen(s);
	end = s + n;
	while (end > s && isspace((unsigned char)end[-1]))
		*--end = '\0';
}

static void strip_trailing_slashes(char *s)
{
	size_t n = strlen(s);

	while (n > 1 && s[n - 1] == '/')
		s[--n] = '\0';
}

static void copy_env_or(char *buf, size_t buflen, const char *env,
			 const char *fallback)
{
	const char *value = getenv(env);

	if (!value || !value[0])
		value = fallback;
	snprintf(buf, buflen, "%s", value);
}

int zlyme_library_roots(zlyme_strlist *out)
{
	const char *file;
	FILE *fp;
	char line[PATH_MAX];

	if (!out)
		return -1;
	out->item = NULL;
	out->count = 0;
	file = getenv("ZLYME_LIBRARIES_FILE");
	if (!file || !file[0])
		file = "/run/zlyme/libraries";
	fp = fopen(file, "r");
	if (fp) {
		while (fgets(line, sizeof(line), fp)) {
			trim_inplace(line);
			strip_trailing_slashes(line);
			if (!line[0])
				continue;
			if (strlist_add(out, line) != 0) {
				fclose(fp);
				return -1;
			}
		}
		fclose(fp);
	}
	if (out->count == 0 && strlist_add(out, "/storage") != 0)
		return -1;
	return 0;
}

const char *zlyme_library_of(const char *path)
{
	static char best[PATH_MAX];
	zlyme_strlist roots;
	int i;
	size_t best_len = 0;

	best[0] = '\0';
	if (!path || zlyme_library_roots(&roots) != 0)
		return best;
	for (i = 0; i < roots.count; i++) {
		size_t len = strlen(roots.item[i]);

		if (len < best_len)
			continue;
		if (strncmp(path, roots.item[i], len) != 0)
			continue;
		if (path[len] != '\0' && path[len] != '/')
			continue;
		snprintf(best, sizeof(best), "%s", roots.item[i]);
		best_len = len;
	}
	zlyme_strlist_free(&roots);
	return best;
}

int zlyme_library_roms_dir(const char *library, char *buf, size_t buflen)
{
	size_t i;

	if (!library || !buf || buflen == 0)
		return 0;
	for (i = 0; i < sizeof(rom_names) / sizeof(rom_names[0]); i++) {
		struct stat st;

		snprintf(buf, buflen, "%s/%s", library, rom_names[i]);
		if (stat(buf, &st) == 0 && S_ISDIR(st.st_mode))
			return 1;
	}
	buf[0] = '\0';
	return 0;
}

void zlyme_state_root(char *buf, size_t buflen)
{
	copy_env_or(buf, buflen, "ZLYME_ZCRAPEGOAT_STATE",
		    "/storage/.config/ZcrapeGoat");
}

void zlyme_cheats_root(char *buf, size_t buflen)
{
	copy_env_or(buf, buflen, "ZLYME_CHEATS_PATH", "/storage/Cheats");
}

static void join2(char *buf, size_t buflen, const char *root, const char *rest)
{
	if (strcmp(root, "/") == 0)
		snprintf(buf, buflen, "/%s", rest);
	else
		snprintf(buf, buflen, "%s/%s", root, rest);
}

void zlyme_settings_path(char *buf, size_t buflen)
{
	char root[PATH_MAX];

	zlyme_state_root(root, sizeof(root));
	join2(buf, buflen, root, "settings.json");
}

void zlyme_overrides_path(char *buf, size_t buflen)
{
	char root[PATH_MAX];

	zlyme_state_root(root, sizeof(root));
	join2(buf, buflen, root, "system_overrides.json");
}

void zlyme_cheat_repo_path(char *buf, size_t buflen)
{
	char root[PATH_MAX];

	zlyme_state_root(root, sizeof(root));
	join2(buf, buflen, root, "libretro-database");
}

void zlyme_daemon_dir(char *buf, size_t buflen)
{
	char root[PATH_MAX];

	zlyme_state_root(root, sizeof(root));
	join2(buf, buflen, root, "daemon");
}

int zlyme_folder_key(const char *console_path, char *buf, size_t buflen)
{
	zlyme_strlist roots;
	int i;

	if (!console_path || !buf || buflen == 0)
		return 0;
	buf[0] = '\0';
	if (zlyme_library_roots(&roots) != 0)
		return 0;
	for (i = 0; i < roots.count; i++) {
		char roms[PATH_MAX];
		size_t len;

		if (!zlyme_library_roms_dir(roots.item[i], roms, sizeof(roms)))
			continue;
		len = strlen(roms);
		if (strncmp(console_path, roms, len) != 0 || console_path[len] != '/')
			continue;
		snprintf(buf, buflen, "%s", console_path + len + 1);
		zlyme_strlist_free(&roots);
		return buf[0] != '\0';
	}
	zlyme_strlist_free(&roots);
	return 0;
}

void zlyme_artwork_path(const char *rom_path, const char *display_name,
			char *buf, size_t buflen)
{
	char dir[PATH_MAX];
	char *slash;

	snprintf(dir, sizeof(dir), "%s", rom_path ? rom_path : "");
	slash = strrchr(dir, '/');
	if (slash && slash != dir)
		*slash = '\0';
	else if (slash == dir)
		slash[1] = '\0';
	snprintf(buf, buflen, "%s/.media/%s.png", dir,
		 display_name ? display_name : "");
}

static const char *base_name(const char *path)
{
	const char *slash = strrchr(path, '/');

	return slash ? slash + 1 : path;
}

int zlyme_system_dirs(zlyme_strlist *out)
{
	zlyme_strlist roots;
	int i;

	if (!out)
		return -1;
	out->item = NULL;
	out->count = 0;
	if (zlyme_library_roots(&roots) != 0)
		return -1;
	for (i = 0; i < roots.count; i++) {
		char roms[PATH_MAX];
		DIR *dir;
		struct dirent *entry;

		if (!zlyme_library_roms_dir(roots.item[i], roms, sizeof(roms)))
			continue;
		dir = opendir(roms);
		if (!dir)
			continue;
		while ((entry = readdir(dir)) != NULL) {
			char full[PATH_MAX];
			struct stat st;
			int seen = 0;
			int j;

			if (strcmp(entry->d_name, ".") == 0 ||
			    strcmp(entry->d_name, "..") == 0)
				continue;
			snprintf(full, sizeof(full), "%s/%s", roms, entry->d_name);
			if (stat(full, &st) != 0 || !S_ISDIR(st.st_mode))
				continue;
			for (j = 0; j < out->count; j++) {
				if (strcmp(base_name(out->item[j]), entry->d_name) == 0) {
					seen = 1;
					break;
				}
			}
			if (seen)
				continue;
			if (strlist_add(out, full) != 0) {
				closedir(dir);
				zlyme_strlist_free(&roots);
				return -1;
			}
		}
		closedir(dir);
	}
	zlyme_strlist_free(&roots);
	return 0;
}

int zlyme_rom_dirs(const char *console_path, zlyme_strlist *out)
{
	const char *base;
	zlyme_strlist roots;
	int i;

	if (!out)
		return -1;
	out->item = NULL;
	out->count = 0;
	if (!console_path)
		return 0;
	base = base_name(console_path);
	if (!base[0])
		return 0;
	if (zlyme_library_roots(&roots) != 0)
		return -1;
	for (i = 0; i < roots.count; i++) {
		char roms[PATH_MAX];
		char full[PATH_MAX];
		struct stat st;

		if (!zlyme_library_roms_dir(roots.item[i], roms, sizeof(roms)))
			continue;
		snprintf(full, sizeof(full), "%s/%s", roms, base);
		if (stat(full, &st) != 0 || !S_ISDIR(st.st_mode))
			continue;
		if (strlist_add(out, full) != 0) {
			zlyme_strlist_free(&roots);
			return -1;
		}
	}
	zlyme_strlist_free(&roots);
	return 0;
}

void zlyme_collision_label(char *label, size_t label_len,
			   const char *display, const char *rom_path)
{
	const char *library = zlyme_library_of(rom_path);
	char next[512];

	if (!library || !library[0])
		library = rom_path ? rom_path : "";
	if (label && label[0])
		snprintf(next, sizeof(next), "%s (%s)", label, library);
	else
		snprintf(next, sizeof(next), "%s (%s)",
			 display ? display : "", library);
	snprintf(label, label_len, "%s", next);
}
