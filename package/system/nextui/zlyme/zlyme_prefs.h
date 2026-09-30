#ifndef ZLYME_PREFS_H
#define ZLYME_PREFS_H

#include <stddef.h>

void prefsReload(void);
/* First hit: ROM rel, then parent folders, then TAG. Empty gov/emu means inherit. */
int prefsLookup(const char *tag, const char *rel, char *gov, size_t gn, char *emu, size_t en);
void prefsGetExact(const char *kind, const char *tag, const char *rel, char *gov, size_t gn, char *emu, size_t en);
void prefsSet(const char *kind, const char *tag, const char *rel, const char *gov, const char *emu);
void prefsClear(const char *kind, const char *tag, const char *rel);
int prefsAlts(const char *tag, char alts[][32], int max);
/* Default launcher id for TAG. 0 when the metadata has no row. */
int prefsDefault(const char *tag, char *id, size_t n);

#endif
