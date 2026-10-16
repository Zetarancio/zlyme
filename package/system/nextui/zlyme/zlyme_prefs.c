#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "zlyme_prefs.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include "defines.h"
#include "utils.h"

#define PREFS_MAX 256
#define PREFS_FILE SHARED_USERDATA_PATH "/zlyme-prefs.txt"
#define ALTS_FILE SYSTEM_PATH "/emu-alts.txt"
#define DEFAULTS_FILE SYSTEM_PATH "/emu-defaults.txt"

typedef struct {
	char kind[8];
	char tag[32];
	char rel[MAX_PATH];
	char governor[16];
	char emu[32];
} Pref;

static Pref prefs[PREFS_MAX];
static int prefs_n;
static int prefs_loaded;
static time_t prefs_mtime;
static off_t prefs_size = -1;
static int prefs_lock_fd = -1;

static void trim_field(char *s)
{
	size_t n;
	if (!s)
		return;
	n = strlen(s);
	while (n && (s[n - 1] == '\n' || s[n - 1] == '\r' || s[n - 1] == ' ' || s[n - 1] == '\t'))
		s[--n] = '\0';
}

static const char *prefs_path(void)
{
	const char *env = getenv("ZLYME_PREFS_FILE");
	if (env && env[0])
		return env;
	return PREFS_FILE;
}

static int prefs_dir(char *buf, size_t n)
{
	const char *path = prefs_path();
	const char *slash = strrchr(path, '/');
	size_t len;

	if (!slash || slash == path) {
		if (n < 2)
			return -1;
		memcpy(buf, ".", 2);
		return 0;
	}
	len = (size_t)(slash - path);
	if (len + 1 > n)
		return -1;
	memcpy(buf, path, len);
	buf[len] = '\0';
	return 0;
}

static void prefs_note_stat(void)
{
	struct stat st;

	if (stat(prefs_path(), &st) == 0) {
		prefs_mtime = st.st_mtime;
		prefs_size = st.st_size;
	} else {
		prefs_mtime = 0;
		prefs_size = -1;
	}
}

static int prefs_lock(void)
{
	char dir[MAX_PATH];
	char path[MAX_PATH];
	int fd;

	if (prefs_lock_fd >= 0)
		return 0;
	if (prefs_dir(dir, sizeof(dir)) != 0)
		return -1;
	if (mkdir(dir, 0755) != 0 && errno != EEXIST)
		return -1;
	if (snprintf(path, sizeof(path), "%s/.zlyme-prefs.lock", dir) >= (int)sizeof(path))
		return -1;
	fd = open(path, O_CREAT | O_RDWR, 0644);
	if (fd < 0)
		return -1;
	if (flock(fd, LOCK_EX) != 0) {
		close(fd);
		return -1;
	}
	prefs_lock_fd = fd;
	return 0;
}

static void prefs_unlock(void)
{
	if (prefs_lock_fd < 0)
		return;
	flock(prefs_lock_fd, LOCK_UN);
	close(prefs_lock_fd);
	prefs_lock_fd = -1;
}

void prefsReload(void)
{
	FILE *f;
	char line[MAX_PATH * 2];

	prefs_n = 0;
	prefs_loaded = 1;
	f = fopen(prefs_path(), "r");
	if (!f) {
		prefs_note_stat();
		return;
	}
	while (fgets(line, sizeof(line), f) && prefs_n < PREFS_MAX) {
		char *kind, *tag, *rel, *gov, *emu, *p;
		trim_field(line);
		if (!line[0] || line[0] == '#')
			continue;
		kind = line;
		p = strchr(kind, '\t');
		if (!p)
			continue;
		*p++ = '\0';
		tag = p;
		p = strchr(tag, '\t');
		if (!p)
			continue;
		*p++ = '\0';
		rel = p;
		p = strchr(rel, '\t');
		if (!p)
			continue;
		*p++ = '\0';
		gov = p;
		p = strchr(gov, '\t');
		if (p) {
			*p++ = '\0';
			emu = p;
		} else {
			emu = "";
		}
		snprintf(prefs[prefs_n].kind, sizeof(prefs[prefs_n].kind), "%s", kind);
		snprintf(prefs[prefs_n].tag, sizeof(prefs[prefs_n].tag), "%s", tag);
		snprintf(prefs[prefs_n].rel, sizeof(prefs[prefs_n].rel), "%s", rel);
		snprintf(prefs[prefs_n].governor, sizeof(prefs[prefs_n].governor), "%s", gov);
		snprintf(prefs[prefs_n].emu, sizeof(prefs[prefs_n].emu), "%s", emu);
		prefs_n++;
	}
	fclose(f);
	prefs_note_stat();
}

static void prefsEnsure(void)
{
	struct stat st;
	const char *path = prefs_path();

	if (prefs_loaded && stat(path, &st) == 0 &&
	    st.st_mtime == prefs_mtime && st.st_size == prefs_size)
		return;
	if (prefs_loaded && stat(path, &st) != 0 && prefs_size < 0)
		return;
	prefsReload();
}

/* Write the in-memory rows. The caller holds the lock and has already
 * reloaded, so this must not read the file again. */
static int prefs_write(void)
{
	char dir[MAX_PATH];
	char tmp[MAX_PATH];
	FILE *f;
	int fd, i, dirfd;

	if (prefs_dir(dir, sizeof(dir)) != 0)
		return -1;
	if (mkdir(dir, 0755) != 0 && errno != EEXIST)
		return -1;
	if (snprintf(tmp, sizeof(tmp), "%s/.zlyme-prefs.XXXXXX", dir) >= (int)sizeof(tmp))
		return -1;
	fd = mkstemp(tmp);
	if (fd < 0)
		return -1;
	f = fdopen(fd, "w");
	if (!f) {
		close(fd);
		unlink(tmp);
		return -1;
	}
	for (i = 0; i < prefs_n; i++) {
		if (fprintf(f, "%s\t%s\t%s\t%s\t%s\n",
			prefs[i].kind, prefs[i].tag, prefs[i].rel,
			prefs[i].governor, prefs[i].emu) < 0) {
			fclose(f);
			unlink(tmp);
			return -1;
		}
	}
	if (fflush(f) != 0) {
		fclose(f);
		unlink(tmp);
		return -1;
	}
	if (fsync(fileno(f)) != 0 && errno != EINVAL && errno != ENOTSUP) {
		fclose(f);
		unlink(tmp);
		return -1;
	}
	if (fclose(f) != 0) {
		unlink(tmp);
		return -1;
	}
	if (rename(tmp, prefs_path()) != 0) {
		unlink(tmp);
		return -1;
	}
	dirfd = open(dir, O_RDONLY | O_DIRECTORY);
	if (dirfd >= 0) {
		if (fsync(dirfd) != 0 && errno != EINVAL && errno != ENOTSUP) {
			close(dirfd);
			return -1;
		}
		close(dirfd);
	}
	prefs_note_stat();
	return 0;
}

void prefsSave(void)
{
	int owned = 0;

	if (prefs_lock_fd < 0) {
		if (prefs_lock() != 0)
			return;
		owned = 1;
		prefsReload();
	}
	if (prefs_write() != 0)
		prefs_loaded = 0;
	if (owned)
		prefs_unlock();
}

static int kind_rank(const char *kind)
{
	if (!strcmp(kind, "rom"))
		return 3;
	if (!strcmp(kind, "folder"))
		return 2;
	return 1;
}

static int rel_is_under(const char *rel, const char *prefix)
{
	size_t n;
	if (!prefix || !prefix[0])
		return 1;
	if (!rel)
		return 0;
	n = strlen(prefix);
	if (strncmp(rel, prefix, n) != 0)
		return 0;
	return rel[n] == '\0' || rel[n] == '/';
}

void prefsGetExact(const char *kind, const char *tag, const char *rel, char *gov, size_t gn, char *emu, size_t en)
{
	int i;

	prefsEnsure();
	if (gov && gn)
		gov[0] = '\0';
	if (emu && en)
		emu[0] = '\0';
	if (!kind || !tag)
		return;
	if (!rel)
		rel = "";
	for (i = 0; i < prefs_n; i++) {
		if (strcmp(prefs[i].kind, kind) != 0)
			continue;
		if (strcasecmp(prefs[i].tag, tag) != 0)
			continue;
		if (strcmp(prefs[i].rel, rel) != 0)
			continue;
		if (gov && gn)
			snprintf(gov, gn, "%s", prefs[i].governor);
		if (emu && en)
			snprintf(emu, en, "%s", prefs[i].emu);
		return;
	}
}

int prefsLookup(const char *tag, const char *rel, char *gov, size_t gn, char *emu, size_t en)
{
	char work[MAX_PATH];
	char *slash;
	int found = 0;

	prefsEnsure();
	if (gov && gn)
		gov[0] = '\0';
	if (emu && en)
		emu[0] = '\0';
	if (!tag || !tag[0])
		return 0;
	if (!rel)
		rel = "";

	if (rel[0]) {
		prefsGetExact("rom", tag, rel, gov, gn, emu, en);
		if ((gov && gov[0]) || (emu && emu[0]))
			return 1;
		snprintf(work, sizeof(work), "%s", rel);
		slash = strrchr(work, '/');
		while (slash) {
			*slash = '\0';
			prefsGetExact("folder", tag, work, gov, gn, emu, en);
			if ((gov && gov[0]) || (emu && emu[0]))
				return 1;
			slash = strrchr(work, '/');
		}
		prefsGetExact("folder", tag, work, gov, gn, emu, en);
		if ((gov && gov[0]) || (emu && emu[0]))
			return 1;
	}
	prefsGetExact("tag", tag, "", gov, gn, emu, en);
	if ((gov && gov[0]) || (emu && emu[0]))
		found = 1;
	(void)rel_is_under;
	(void)kind_rank;
	return found;
}

void prefsSet(const char *kind, const char *tag, const char *rel, const char *gov, const char *emu)
{
	int i;

	if (!kind || !tag)
		return;
	if (!rel)
		rel = "";
	if (!gov)
		gov = "";
	if (!emu)
		emu = "";
	if (prefs_lock() != 0)
		return;
	prefsReload();
	for (i = 0; i < prefs_n; i++) {
		if (strcmp(prefs[i].kind, kind) == 0 &&
		    strcasecmp(prefs[i].tag, tag) == 0 &&
		    strcmp(prefs[i].rel, rel) == 0) {
			snprintf(prefs[i].governor, sizeof(prefs[i].governor), "%s", gov);
			snprintf(prefs[i].emu, sizeof(prefs[i].emu), "%s", emu);
			prefsSave();
			prefs_unlock();
			return;
		}
	}
	if (prefs_n >= PREFS_MAX) {
		prefs_unlock();
		return;
	}
	snprintf(prefs[prefs_n].kind, sizeof(prefs[prefs_n].kind), "%s", kind);
	snprintf(prefs[prefs_n].tag, sizeof(prefs[prefs_n].tag), "%s", tag);
	snprintf(prefs[prefs_n].rel, sizeof(prefs[prefs_n].rel), "%s", rel);
	snprintf(prefs[prefs_n].governor, sizeof(prefs[prefs_n].governor), "%s", gov);
	snprintf(prefs[prefs_n].emu, sizeof(prefs[prefs_n].emu), "%s", emu);
	prefs_n++;
	prefsSave();
	prefs_unlock();
}

void prefsClear(const char *kind, const char *tag, const char *rel)
{
	int i;

	if (!kind || !tag)
		return;
	if (!rel)
		rel = "";
	if (prefs_lock() != 0)
		return;
	prefsReload();
	for (i = 0; i < prefs_n; i++) {
		if (strcmp(prefs[i].kind, kind) == 0 &&
		    strcasecmp(prefs[i].tag, tag) == 0 &&
		    strcmp(prefs[i].rel, rel) == 0) {
			prefs[i] = prefs[prefs_n - 1];
			prefs_n--;
			prefsSave();
			prefs_unlock();
			return;
		}
	}
	prefs_unlock();
}

int prefsAlts(const char *tag, char alts[][32], int max)
{
	FILE *f;
	char line[256];
	int n = 0;

	if (!tag || !alts || max < 1)
		return 0;
	f = fopen(ALTS_FILE, "r");
	if (!f)
		return 0;
	while (fgets(line, sizeof(line), f)) {
		char *p, *tok;
		trim_field(line);
		if (!line[0] || line[0] == '#')
			continue;
		p = line;
		tok = strsep(&p, " \t");
		if (!tok || strcasecmp(tok, tag) != 0)
			continue;
		while (p && n < max) {
			while (*p == ' ' || *p == '\t')
				p++;
			if (!*p)
				break;
			tok = strsep(&p, " \t");
			if (!tok || !tok[0])
				continue;
			snprintf(alts[n], 32, "%s", tok);
			n++;
		}
		break;
	}
	fclose(f);
	return n;
}

int prefsDefault(const char *tag, char *id, size_t n)
{
	FILE *f;
	char line[256];

	if (!tag || !id || n < 2)
		return 0;
	id[0] = '\0';
	f = fopen(DEFAULTS_FILE, "r");
	if (!f)
		return 0;
	while (fgets(line, sizeof(line), f)) {
		char *p, *tok, *val;
		trim_field(line);
		if (!line[0] || line[0] == '#')
			continue;
		p = line;
		tok = strsep(&p, " \t");
		if (!tok || strcasecmp(tok, tag) != 0)
			continue;
		while (p && (*p == ' ' || *p == '\t'))
			p++;
		val = strsep(&p, " \t");
		if (val && val[0])
			snprintf(id, n, "%s", val);
		break;
	}
	fclose(f);
	return id[0] ? 1 : 0;
}
