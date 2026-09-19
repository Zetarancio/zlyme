#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "zlyme_prefs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "defines.h"
#include "utils.h"

#define PREFS_MAX 256
#define PREFS_FILE SHARED_USERDATA_PATH "/zlyme-prefs.txt"
#define ALTS_FILE SYSTEM_PATH "/emu-alts.txt"

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

static void trim_field(char *s)
{
	size_t n;
	if (!s)
		return;
	n = strlen(s);
	while (n && (s[n - 1] == '\n' || s[n - 1] == '\r' || s[n - 1] == ' ' || s[n - 1] == '\t'))
		s[--n] = '\0';
}

void prefsReload(void)
{
	FILE *f;
	char line[MAX_PATH * 2];

	prefs_n = 0;
	prefs_loaded = 1;
	f = fopen(PREFS_FILE, "r");
	if (!f)
		return;
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
}

static void prefsEnsure(void)
{
	if (!prefs_loaded)
		prefsReload();
}

void prefsSave(void)
{
	FILE *f;
	int i;
	char dir[MAX_PATH];

	prefsEnsure();
	snprintf(dir, sizeof(dir), "%s", SHARED_USERDATA_PATH);
	mkdir(dir, 0755);
	f = fopen(PREFS_FILE, "w");
	if (!f)
		return;
	for (i = 0; i < prefs_n; i++) {
		fprintf(f, "%s\t%s\t%s\t%s\t%s\n",
			prefs[i].kind, prefs[i].tag, prefs[i].rel,
			prefs[i].governor, prefs[i].emu);
	}
	fclose(f);
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

	prefsEnsure();
	if (!kind || !tag)
		return;
	if (!rel)
		rel = "";
	if (!gov)
		gov = "";
	if (!emu)
		emu = "";
	for (i = 0; i < prefs_n; i++) {
		if (strcmp(prefs[i].kind, kind) == 0 &&
		    strcasecmp(prefs[i].tag, tag) == 0 &&
		    strcmp(prefs[i].rel, rel) == 0) {
			snprintf(prefs[i].governor, sizeof(prefs[i].governor), "%s", gov);
			snprintf(prefs[i].emu, sizeof(prefs[i].emu), "%s", emu);
			prefsSave();
			return;
		}
	}
	if (prefs_n >= PREFS_MAX)
		return;
	snprintf(prefs[prefs_n].kind, sizeof(prefs[prefs_n].kind), "%s", kind);
	snprintf(prefs[prefs_n].tag, sizeof(prefs[prefs_n].tag), "%s", tag);
	snprintf(prefs[prefs_n].rel, sizeof(prefs[prefs_n].rel), "%s", rel);
	snprintf(prefs[prefs_n].governor, sizeof(prefs[prefs_n].governor), "%s", gov);
	snprintf(prefs[prefs_n].emu, sizeof(prefs[prefs_n].emu), "%s", emu);
	prefs_n++;
	prefsSave();
}

void prefsClear(const char *kind, const char *tag, const char *rel)
{
	int i;

	prefsEnsure();
	if (!kind || !tag)
		return;
	if (!rel)
		rel = "";
	for (i = 0; i < prefs_n; i++) {
		if (strcmp(prefs[i].kind, kind) == 0 &&
		    strcasecmp(prefs[i].tag, tag) == 0 &&
		    strcmp(prefs[i].rel, rel) == 0) {
			prefs[i] = prefs[prefs_n - 1];
			prefs_n--;
			prefsSave();
			return;
		}
	}
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
