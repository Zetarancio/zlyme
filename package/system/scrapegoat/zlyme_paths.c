#include "zlyme_paths.h"

#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic ignored "-Wformat-truncation"
#endif

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void trim(char *s)
{
	size_t n;
	char *end;

	while (*s && isspace((unsigned char)*s))
		memmove(s, s + 1, strlen(s));
	n = strlen(s);
	end = s + n;
	while (end > s && isspace((unsigned char)end[-1]))
		*--end = '\0';
}

static void copy_env_or(char *buf, size_t buflen, const char *env,
			 const char *fallback)
{
	const char *value = getenv(env);

	if (!value || !value[0])
		value = fallback;
	snprintf(buf, buflen, "%s", value);
}

int zlyme_library_roots(char roots[][PATH_MAX], int max)
{
	const char *file;
	FILE *fp;
	char line[PATH_MAX];
	int count = 0;

	if (max <= 0)
		return 0;
	file = getenv("ZLYME_LIBRARIES_FILE");
	if (!file || !file[0])
		file = "/run/zlyme/libraries";
	fp = fopen(file, "r");
	if (fp) {
		while (count < max && fgets(line, sizeof(line), fp)) {
			trim(line);
			if (!line[0])
				continue;
			snprintf(roots[count], PATH_MAX, "%s", line);
			count++;
		}
		fclose(fp);
	}
	if (count == 0)
		snprintf(roots[count++], PATH_MAX, "%s", "/storage");
	return count;
}

const char *zlyme_library_of(const char *path)
{
	static char best[PATH_MAX];
	char roots[8][PATH_MAX];
	int n;
	int i;
	size_t best_len = 0;

	best[0] = '\0';
	if (!path)
		return best;
	n = zlyme_library_roots(roots, 8);
	for (i = 0; i < n; i++) {
		size_t len = strlen(roots[i]);

		if (len < best_len)
			continue;
		if (strncmp(path, roots[i], len) != 0)
			continue;
		if (path[len] != '\0' && path[len] != '/')
			continue;
		snprintf(best, sizeof(best), "%s", roots[i]);
		best_len = len;
	}
	return best;
}

void zlyme_state_root(char *buf, size_t buflen)
{
	copy_env_or(buf, buflen, "ZLYME_SCRAPEGOAT_STATE",
		    "/storage/.config/ScrapeGoat");
}

void zlyme_cheats_root(char *buf, size_t buflen)
{
	copy_env_or(buf, buflen, "ZLYME_CHEATS_PATH", "/storage/Cheats");
}

static void join2(char *buf, size_t buflen, const char *root, const char *rest)
{
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
	char roots[8][PATH_MAX];
	int n;
	int i;

	if (!console_path || !buf || buflen == 0)
		return 0;
	buf[0] = '\0';
	n = zlyme_library_roots(roots, 8);
	for (i = 0; i < n; i++) {
		char roms[PATH_MAX];
		size_t len;

		snprintf(roms, sizeof(roms), "%s/Roms", roots[i]);
		len = strlen(roms);
		if (strncmp(console_path, roms, len) != 0 || console_path[len] != '/')
			continue;
		snprintf(buf, buflen, "%s", console_path + len + 1);
		return buf[0] != '\0';
	}
	return 0;
}

void zlyme_artwork_path(const char *rom_path, const char *display_name,
			char *buf, size_t buflen)
{
	char dir[PATH_MAX];
	char *slash;

	snprintf(dir, sizeof(dir), "%s", rom_path ? rom_path : "");
	slash = strrchr(dir, '/');
	if (slash)
		*slash = '\0';
	snprintf(buf, buflen, "%s/.media/%s.png", dir,
		 display_name ? display_name : "");
}

static int already_have(char paths[][PATH_MAX], int count, const char *full)
{
	const char *base = strrchr(full, '/');
	int i;

	base = base ? base + 1 : full;
	for (i = 0; i < count; i++) {
		const char *have = strrchr(paths[i], '/');

		have = have ? have + 1 : paths[i];
		if (strcmp(have, base) == 0)
			return 1;
	}
	return 0;
}

int zlyme_system_dirs(char paths[][PATH_MAX], int max)
{
	char roots[8][PATH_MAX];
	int roots_n;
	int count = 0;
	int i;

	roots_n = zlyme_library_roots(roots, 8);
	for (i = 0; i < roots_n && count < max; i++) {
		char roms[PATH_MAX];
		DIR *dir;
		struct dirent *entry;

		snprintf(roms, sizeof(roms), "%s/Roms", roots[i]);
		dir = opendir(roms);
		if (!dir)
			continue;
		while (count < max && (entry = readdir(dir)) != NULL) {
			char full[PATH_MAX];
			struct stat st;

			if (entry->d_name[0] == '.')
				continue;
			snprintf(full, sizeof(full), "%s/%s", roms, entry->d_name);
			if (stat(full, &st) != 0 || !S_ISDIR(st.st_mode))
				continue;
			if (already_have(paths, count, full))
				continue;
			snprintf(paths[count], PATH_MAX, "%s", full);
			count++;
		}
		closedir(dir);
	}
	return count;
}

int zlyme_rom_dirs(const char *console_path, char dirs[][PATH_MAX], int max)
{
	const char *base;
	char roots[8][PATH_MAX];
	int roots_n;
	int count = 0;
	int i;

	if (!console_path || max <= 0)
		return 0;
	base = strrchr(console_path, '/');
	base = base ? base + 1 : console_path;
	if (!base[0])
		return 0;
	roots_n = zlyme_library_roots(roots, 8);
	for (i = 0; i < roots_n && count < max; i++) {
		char full[PATH_MAX];
		struct stat st;

		snprintf(full, sizeof(full), "%s/Roms/%s", roots[i], base);
		if (stat(full, &st) != 0 || !S_ISDIR(st.st_mode))
			continue;
		snprintf(dirs[count], PATH_MAX, "%s", full);
		count++;
	}
	return count;
}

void zlyme_collision_label(char *label, size_t label_len,
			   const char *display, const char *rom_path)
{
	const char *library = zlyme_library_of(rom_path);
	char next[256];

	if (!library || !library[0])
		library = rom_path ? rom_path : "";
	if (label && label[0])
		snprintf(next, sizeof(next), "%s (%s)", label, library);
	else
		snprintf(next, sizeof(next), "%s (%s)",
			 display ? display : "", library);
	snprintf(label, label_len, "%s", next);
}

static void mkdir_parents(const char *file)
{
	char dir[PATH_MAX];
	char *slash;

	snprintf(dir, sizeof(dir), "%s", file);
	slash = strrchr(dir, '/');
	if (!slash)
		return;
	*slash = '\0';
	slash = dir + 1;
	while ((slash = strchr(slash, '/')) != NULL) {
		*slash = '\0';
		mkdir(dir, 0755);
		*slash++ = '/';
	}
	mkdir(dir, 0755);
}

static void copy_if_missing(const char *dest, const char *src)
{
	FILE *in;
	FILE *out;
	char buf[4096];
	size_t n;

	if (!dest || !src || access(dest, F_OK) == 0 || access(src, R_OK) != 0)
		return;
	in = fopen(src, "rb");
	if (!in)
		return;
	mkdir_parents(dest);
	out = fopen(dest, "wb");
	if (!out) {
		fclose(in);
		return;
	}
	while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
		if (fwrite(buf, 1, n, out) != n)
			break;
	}
	fclose(in);
	fclose(out);
}

void zlyme_import_legacy(void)
{
	char legacy[PATH_MAX];
	char dest[PATH_MAX];
	char src[PATH_MAX];

	copy_env_or(legacy, sizeof(legacy), "ZLYME_SCRAPEGOAT_LEGACY",
		    "/storage/.userdata/shared/ScrapeGoat");
	zlyme_settings_path(dest, sizeof(dest));
	snprintf(src, sizeof(src), "%s/settings.json", legacy);
	copy_if_missing(dest, src);
	zlyme_overrides_path(dest, sizeof(dest));
	snprintf(src, sizeof(src), "%s/system_overrides.json", legacy);
	copy_if_missing(dest, src);
}
