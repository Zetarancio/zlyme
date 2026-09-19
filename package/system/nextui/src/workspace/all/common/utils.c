#ifndef _GNU_SOURCE
#define _GNU_SOURCE // for strcasestr
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <ctype.h>
#include <dirent.h>
#include <stdint.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include "defines.h"
#include "utils.h"

///////////////////////////////////////

int prefixMatch(char* pre, const char* str) {
	return (strncasecmp(pre,str,strlen(pre))==0);
}
int suffixMatch(char* suf, const char* str) {
	int len = strlen(suf);
	int offset = strlen(str)-len;
	return (offset>=0 && strncasecmp(suf, str+offset, len)==0);
}
int exactMatch(const char* str1, const char* str2) {
	if (!str1 || !str2) return 0; // NULL isn't safe here
	int len1 = strlen(str1);
	if (len1!=strlen(str2)) return 0;
	return (strncmp(str1,str2,len1)==0);
}
int containsString(char* haystack, char* needle) {
	return strcasestr(haystack, needle) != NULL;
}
int hide(char* file_name) {
	return file_name[0]=='.' || file_name[0]=='_' || suffixMatch(".disabled", file_name) || exactMatch("map.txt", file_name);
}

int isJunkDir(const char* name) {
	if (!name || !name[0]) return 0;
	return exactMatch(name, "Imgs") || exactMatch(name, "imgs") ||
		exactMatch(name, "images") || exactMatch(name, "manuals") ||
		exactMatch(name, "videos") || exactMatch(name, "media") ||
		exactMatch(name, "boxart") || exactMatch(name, "artwork");
}

#define ROMEXTS_MAX 48
#define ROMEXTS_TAG 16
#define ROMEXTS_LINE 384

typedef struct {
	char tag[ROMEXTS_TAG];
	char exts[ROMEXTS_LINE];
} RomExtRule;

static RomExtRule rom_exts[ROMEXTS_MAX];
static int rom_exts_n;
static int rom_exts_loaded;

static int isJunkFile(const char* name) {
	static const char *junk[] = {
		".srm", ".sav", ".state", ".auto", ".png", ".jpg", ".jpeg", ".gif",
		".webp", ".bmp", ".txt", ".nfo", ".xml", ".dat", ".db", ".ini",
		".cfg", ".json", ".md", ".html", ".url", ".log", ".cht", ".lpl",
		".bak", ".mp4", ".pdf", ".desktop", NULL
	};
	if (!name || hide((char *)name)) return 1;
	for (int i = 0; junk[i]; i++) {
		if (suffixMatch((char *)junk[i], (char *)name)) return 1;
	}
	return 0;
}

static void loadRomExtsOnce(void) {
	if (rom_exts_loaded) return;
	rom_exts_loaded = 1;
	const char *paths[] = {
		"/usr/share/nextui/rom-exts.txt",
		SYSTEM_PATH "/rom-exts.txt",
		NULL
	};
	FILE *f = NULL;
	for (int i = 0; paths[i]; i++) {
		f = fopen(paths[i], "r");
		if (f) break;
	}
	if (!f) return;
	char line[ROMEXTS_LINE + 32];
	while (fgets(line, sizeof(line), f) && rom_exts_n < ROMEXTS_MAX) {
		normalizeNewline(line);
		trimTrailingNewlines(line);
		if (!line[0] || line[0] == '#') continue;
		char *colon = strchr(line, ':');
		if (!colon) continue;
		*colon = '\0';
		char *tag = line;
		char *exts = colon + 1;
		while (*tag == ' ' || *tag == '\t') tag++;
		while (*exts == ' ' || *exts == '\t') exts++;
		if (!tag[0] || !exts[0]) continue;
		snprintf(rom_exts[rom_exts_n].tag, sizeof(rom_exts[rom_exts_n].tag), "%s", tag);
		snprintf(rom_exts[rom_exts_n].exts, sizeof(rom_exts[rom_exts_n].exts), "%s", exts);
		rom_exts_n++;
	}
	fclose(f);
}

int isAllowedRom(const char* emu_tag, const char* file_name) {
	if (!file_name || !file_name[0]) return 0;
	if (isJunkFile(file_name)) return 0;
	loadRomExtsOnce();
	if (!emu_tag || !emu_tag[0] || rom_exts_n == 0) return 1;
	const char *exts = NULL;
	for (int i = 0; i < rom_exts_n; i++) {
		if (exactMatch(rom_exts[i].tag, emu_tag)) {
			exts = rom_exts[i].exts;
			break;
		}
	}
	if (!exts) return 1;
	const char *dot = strrchr(file_name, '.');
	if (!dot || !dot[1] || strchr(dot + 1, '/')) return 0;
	char ext[32];
	snprintf(ext, sizeof(ext), "%s", dot + 1);
	for (char *p = ext; *p; p++)
		*p = (char)tolower((unsigned char)*p);
	char buf[ROMEXTS_LINE];
	snprintf(buf, sizeof(buf), "%s", exts);
	char *save = NULL;
	for (char *tok = strtok_r(buf, " \t", &save); tok; tok = strtok_r(NULL, " \t", &save)) {
		if (strcasecmp(tok, ext) == 0) return 1;
	}
	return 0;
}

int skipCompanionDisc(const char* dir, const char* name) {
	if (!dir || !name) return 0;
	if (!(suffixMatch(".bin", (char *)name) || suffixMatch(".img", (char *)name) ||
	      suffixMatch(".iso", (char *)name) || suffixMatch(".raw", (char *)name)))
		return 0;
	char stem[256];
	snprintf(stem, sizeof(stem), "%s", name);
	char *dot = strrchr(stem, '.');
	if (dot) *dot = '\0';
	char probe[512];
	snprintf(probe, sizeof(probe), "%s/%s.cue", dir, stem);
	if (exists(probe)) return 1;
	snprintf(probe, sizeof(probe), "%s/%s.m3u", dir, stem);
	if (exists(probe)) return 1;
	snprintf(probe, sizeof(probe), "%s/%s.ccd", dir, stem);
	if (exists(probe)) return 1;
	return 0;
}

/* MinUI/NextUI multi-disc: Game.m3u sits next to Game/. Do not list the
 * folder; the playlist is the game. PPSSPP also drops a memstick tree
 * (PSP/SYSTEM, SAVEDATA, …) next to ISOs — hide that, not a game named GAME. */
int skipCompanionFolder(const char* dir, const char* name) {
	char probe[512];
	if (!dir || !name || !name[0]) return 0;
	if (exactMatch((char *)name, "PSP") || exactMatch((char *)name, "PPSSPP") ||
	    exactMatch((char *)name, "SYSTEM") || exactMatch((char *)name, "SAVEDATA") ||
	    exactMatch((char *)name, "CHEATS") || exactMatch((char *)name, "TEXTURES") ||
	    exactMatch((char *)name, "PPSSPP_STATE"))
		return 1;
	snprintf(probe, sizeof(probe), "%s/%s.m3u", dir, name);
	return exists(probe);
}

char *splitString(char *str, const char *delim)
{
    char *p = strstr(str, delim);
    if (p == NULL)
        return NULL;          // delimiter not found
    *p = '\0';                // terminate string after head
    return p + strlen(delim); // return tail substring
}
void truncateString(char *string, size_t max_len) {
	size_t len = strlen(string) + 1;
	if (len <= max_len) return;

	strncpy(&string[max_len - 4], "...\0", 4);
}
void wrapString(char *string, size_t max_len, size_t max_lines) {
	char *line = string;

	for (size_t i = 1; i < max_lines; i++) {
		char *p = line;
		char *prev;
		do {
			prev = p;
			p = strchr(prev+1, ' ');
		} while (p && p - line < (int)max_len);

		if (!p && strlen(line) < max_len) break;

		if (prev && prev != line) {
			line = prev + 1;
			*prev = '\n';
		}
	}
	truncateString(line, max_len);
}
// TODO: verify this yields the same result as the one in minui.c, remove one
// This one does not modify the input, cause we arent savages
char *replaceString2(const char *orig, char *rep, char *with)
{
    const char *ins;     // the next insert point
    char *tmp;     // varies
    int len_rep;   // length of rep (the string to remove)
    int len_with;  // length of with (the string to replace rep with)
    int len_front; // distance between rep and end of last rep
    int count;     // number of replacements

    // sanity checks and initialization
    if (!orig || !rep)
        return NULL;
    len_rep = strlen(rep);
    if (len_rep == 0)
        return NULL; // empty rep causes infinite loop during count
    if (!with)
        with = "";
    len_with = strlen(with);

    // count the number of replacements needed
    ins = orig;
    for (count = 0; (tmp = strstr(ins, rep)); ++count)
        ins = tmp + len_rep;

    char *result =
        (char *)malloc(strlen(orig) + (len_with - len_rep) * count + 1);
    tmp = result;

    if (!result)
        return NULL;

    // first time through the loop, all the variable are set correctly
    // from here on,
    //    tmp points to the end of the result string
    //    ins points to the next occurrence of rep in orig
    //    orig points to the remainder of orig after "end of rep"
    while (count--) {
        ins = strstr(orig, rep);
        len_front = ins - orig;
        tmp = strncpy(tmp, orig, len_front) + len_front;
        tmp = strcpy(tmp, with) + len_with;
        orig += len_front + len_rep; // move to next "end of rep"
    }
    strcpy(tmp, orig);
    return result;
}
// Stores the trimmed input string into the given output buffer, which must be
// large enough to store the result.  If it is too small, the output is
// truncated.
size_t trimString(char *out, size_t len, const char *str, bool first)
{
    if (len == 0)
        return 0;

    const char *end;
    size_t out_size;
    bool is_string = false;

    // Trim leading space
    while (strchr("\r\n\t {},", (unsigned char)*str) != NULL)
        str++;

    end = str + 1;

    if ((unsigned char)*str == '"') {
        is_string = true;
        str++;
        while (strchr("\r\n\"", (unsigned char)*end) == NULL)
            end++;
    }

    if (*str == 0) // All spaces?
    {
        *out = 0;
        return 1;
    }

    // Trim trailing space
    if (first)
        while (strchr("\r\n\t {},", (unsigned char)*end) == NULL)
            end++;
    else {
        end = str + strlen(str) - 1;
        while (end > str && strchr("\r\n\t {},", (unsigned char)*end) != NULL)
            end--;
        end++;
    }

    if (is_string && (unsigned char)*(end - 1) == '"')
        end--;

    // Set output size to minimum of trimmed string length and buffer size minus
    // 1
    out_size = (end - str) < len - 1 ? (end - str) : len - 1;

    // Copy trimmed string and add null terminator
    memcpy(out, str, out_size);
    out[out_size] = 0;

    return out_size;
}

void removeParentheses(char *str_out, const char *str_in)
{
    char temp[STR_MAX];
    int len = strlen(str_in);
    int c = 0;
    bool inside = false;
    char end_char;

    for (int i = 0; i < len && i < STR_MAX; i++) {
        if (!inside && (str_in[i] == '(' || str_in[i] == '[')) {
            end_char = str_in[i] == '(' ? ')' : ']';
            inside = true;
            continue;
        }
        else if (inside) {
            if (str_in[i] == end_char)
                inside = false;
            continue;
        }
        temp[c++] = str_in[i];
    }

    temp[c] = '\0';

    trimString(str_out, STR_MAX - 1, temp, false);
}
void serializeTime(char *dest_str, int nTime)
{
    if (nTime >= 60) {
        int h = nTime / 3600;
        int m = (nTime - 3600 * h) / 60;
        if (h > 0) {
            sprintf(dest_str, "%dh %dm", h, m);
        }
        else {
            sprintf(dest_str, "%dm %ds", m, nTime - 60 * m);
        }
    }
    else {
        sprintf(dest_str, "%ds", nTime);
    }
}
int countChar(const char *str, char ch)
{
    int i, count = 0;
    for (i = 0; i <= strlen(str); i++) {
        if (str[i] == ch) {
            count++;
        }
    }
    return count;
}
char *removeExtension(const char *myStr)
{
    if (myStr == NULL)
        return NULL;
    char *retStr = (char *)malloc(strlen(myStr) + 1);
    char *lastExt;
    if (retStr == NULL)
        return NULL;
    strcpy(retStr, myStr);
    if ((lastExt = strrchr(retStr, '.')) != NULL && *(lastExt + 1) != ' ' && *(lastExt + 2) != '\0')
        *lastExt = '\0';
    return retStr;
}
const char *baseName(const char *filename)
{
    char *p = strrchr(filename, '/');
    return p ? p + 1 : (char *)filename;
}
void folderPath(const char *path, char *result) {
    char pathCopy[256];  
    strcpy(pathCopy, path);

    char *lastSlash = strrchr(pathCopy, '/');  // Find the last slash
    if (lastSlash != NULL) {
        *lastSlash = '\0';  // Cut off the filename
        strcpy(result, pathCopy);  // Copy the remaining path
    } else {
        strcpy(result, "");  // No folder found
    }
}
void cleanName(char *name_out, const char *file_name)
{
    char *name_without_ext = removeExtension(file_name);
    char *no_underscores = replaceString2(name_without_ext, "_", " ");
    char *dot_ptr = strstr(no_underscores, ".");
    if (dot_ptr != NULL) {
        char *s = no_underscores;
        while (isdigit(*s) && s < dot_ptr)
            s++;
        if (s != dot_ptr)
            dot_ptr = no_underscores;
        else {
            dot_ptr++;
            if (dot_ptr[0] == ' ')
                dot_ptr++;
        }
    }
    else {
        dot_ptr = no_underscores;
    }
    removeParentheses(name_out, dot_ptr);
    free(name_without_ext);
    free(no_underscores);
}
bool pathRelativeTo(char *path_out, const char *dir_from, const char *file_to)
{
    path_out[0] = '\0';

    char abs_from[MAX_PATH];
    char abs_to[MAX_PATH];
    if (realpath(dir_from, abs_from) == NULL || realpath(file_to, abs_to) == NULL) {
        return false;
    }

    char *p1 = abs_from;
    char *p2 = abs_to;
    while (*p1 && (*p1 == *p2)) {
        ++p1, ++p2;
    }

    if (*p2 == '/') {
        ++p2;
    }

    if (strlen(p1) > 0) {
        int num_parens = countChar(p1, '/') + 1;
        for (int i = 0; i < num_parens; i++) {
            strcat(path_out, "../");
        }
    }
    strcat(path_out, p2);

    return true;
}

void getDisplayName(const char* in_name, char* out_name) {
	char* tmp;
	char work_name[256];
	strcpy(work_name, in_name);
	strcpy(out_name, in_name);
	
	if (suffixMatch("/" PLATFORM, work_name)) { // hide platform from Tools path...
		tmp = strrchr(work_name, '/');
		tmp[0] = '\0';
	}
	
	// extract just the filename if necessary
	tmp = strrchr(work_name, '/');
	if (tmp) strcpy(out_name, tmp+1);
	
	// remove extension(s), eg. .p8.png
	while ((tmp = strrchr(out_name, '.'))!=NULL) {
		int len = strlen(tmp);
		if (len>2 && len<=5) tmp[0] = '\0'; // 1-4 letter extension plus dot (was 1-3, extended for .doom files)
		else break;
	}
	
	// remove trailing parens (round and square)
	strcpy(work_name, out_name);
	while ((tmp=strrchr(out_name, '('))!=NULL || (tmp=strrchr(out_name, '['))!=NULL) {
		if (tmp==out_name) break;
		tmp[0] = '\0';
		tmp = out_name;
	}
	
	// make sure we haven't nuked the entire name
	if (out_name[0]=='\0') strcpy(out_name, work_name);
	
	// remove trailing whitespace
	tmp = out_name + strlen(out_name) - 1;
    while(tmp>out_name && isspace((unsigned char)*tmp)) tmp--;
    tmp[1] = '\0';
}
#define LIBRARY_MAX 8
#define LIBRARIES_FILE "/run/zlyme/libraries"

static char library_roots[LIBRARY_MAX][MAX_PATH];
static int library_n;
static int library_loaded;

void libraryReload(void)
{
	library_n = 0;
	library_loaded = 1;
	FILE *f = fopen(LIBRARIES_FILE, "r");
	if (f) {
		char line[MAX_PATH];
		while (fgets(line, sizeof(line), f) && library_n < LIBRARY_MAX) {
			trimTrailingNewlines(line);
			if (!line[0])
				continue;
			if (access(line, F_OK) != 0)
				continue;
			snprintf(library_roots[library_n], MAX_PATH, "%s", line);
			library_n++;
		}
		fclose(f);
	}
	if (library_n == 0) {
		snprintf(library_roots[0], MAX_PATH, "%s", SDCARD_PATH);
		library_n = 1;
	}
}

int libraryCount(void)
{
	if (!library_loaded)
		libraryReload();
	return library_n;
}

const char *libraryRoot(int i)
{
	if (!library_loaded)
		libraryReload();
	if (i < 0 || i >= library_n)
		return SDCARD_PATH;
	return library_roots[i];
}

int libraryRomsDir(int i, char *out, size_t n)
{
	const char *root = libraryRoot(i);
	if (!out || n == 0)
		return 0;
	snprintf(out, n, "%s/Roms", root);
	if (exists(out))
		return 1;
	snprintf(out, n, "%s/roms", root);
	if (exists(out))
		return 1;
	snprintf(out, n, "%s/ROMS", root);
	if (exists(out))
		return 1;
	out[0] = '\0';
	return 0;
}

int pathUnderLibraryRoms(const char *path)
{
	char roms[MAX_PATH];
	int i, n;
	size_t len;

	if (!path)
		return 0;
	if (prefixMatch(ROMS_PATH, path))
		return 1;
	n = libraryCount();
	for (i = 0; i < n; i++) {
		if (!libraryRomsDir(i, roms, sizeof(roms)))
			continue;
		len = strlen(roms);
		if (strncasecmp(path, roms, len) == 0 && (path[len] == '\0' || path[len] == '/'))
			return 1;
	}
	return 0;
}

int isLibraryRomsDir(const char *path)
{
	char roms[MAX_PATH];
	int i, n;

	if (!path)
		return 0;
	if (exactMatch(path, ROMS_PATH))
		return 1;
	n = libraryCount();
	for (i = 0; i < n; i++) {
		if (!libraryRomsDir(i, roms, sizeof(roms)))
			continue;
		if (exactMatch(path, roms))
			return 1;
	}
	return 0;
}

void libraryBadge(const char *path, char *out, size_t n)
{
	const char *p;
	const char *slash;
	size_t len;

	if (!out || n == 0)
		return;
	out[0] = '\0';
	if (!path)
		return;
	if (prefixMatch((char *)"/mnt/sd2", path)) {
		snprintf(out, n, "SD2");
		return;
	}
	if (prefixMatch((char *)"/mnt/media/", path)) {
		p = path + strlen("/mnt/media/");
		slash = strchr(p, '/');
		len = slash ? (size_t)(slash - p) : strlen(p);
		if (len >= n)
			len = n - 1;
		memcpy(out, p, len);
		out[len] = '\0';
	}
}

void pathFromRecent(const char *stored, char *out, size_t n)
{
	if (!out || n == 0)
		return;
	out[0] = '\0';
	if (!stored)
		return;
	if (stored[0] == '/' && (prefixMatch((char *)"/mnt/", stored) || prefixMatch(SDCARD_PATH, stored))) {
		snprintf(out, n, "%s", stored);
		return;
	}
	snprintf(out, n, "%s%s", SDCARD_PATH, stored);
}

int consoleRelFromPath(const char *path, char *tag, size_t tag_n, char *rel, size_t rel_n)
{
	char roms[MAX_PATH];
	const char *rest = NULL;
	size_t len;
	char *slash;
	int i, n;
	char console[MAX_PATH];

	if (tag && tag_n)
		tag[0] = '\0';
	if (rel && rel_n)
		rel[0] = '\0';
	if (!path)
		return 0;

	n = libraryCount();
	for (i = 0; i < n; i++) {
		if (!libraryRomsDir(i, roms, sizeof(roms)))
			continue;
		len = strlen(roms);
		if (strncasecmp(path, roms, len) == 0 && path[len] == '/') {
			rest = path + len + 1;
			break;
		}
	}
	if (!rest && prefixMatch(ROMS_PATH, path) && path[strlen(ROMS_PATH)] == '/')
		rest = path + strlen(ROMS_PATH) + 1;
	if (!rest)
		return 0;

	slash = strchr((char *)rest, '/');
	if (slash) {
		len = (size_t)(slash - rest);
		if (len >= sizeof(console))
			len = sizeof(console) - 1;
		memcpy(console, rest, len);
		console[len] = '\0';
		if (rel && rel_n && slash[1])
			snprintf(rel, rel_n, "%s", slash + 1);
	} else {
		snprintf(console, sizeof(console), "%s", rest);
	}
	if (tag && tag_n) {
		char emu[MAX_PATH];
		getEmuName(console, emu);
		snprintf(tag, tag_n, "%s", emu);
	}
	return 1;
}

void getEmuName(const char* in_name, char* out_name) { // NOTE: both char arrays need to be MAX_PATH length!
	char* tmp;
	char roms[MAX_PATH];
	int i, n;
	size_t len;

	strcpy(out_name, in_name);
	tmp = out_name;

	n = libraryCount();
	for (i = 0; i < n; i++) {
		if (!libraryRomsDir(i, roms, sizeof(roms)))
			continue;
		len = strlen(roms);
		if (strncasecmp(tmp, roms, len) == 0 && (tmp[len] == '/' || tmp[len] == '\0')) {
			tmp += len;
			if (*tmp == '/')
				tmp++;
			char* tmp2 = strchr(tmp, '/');
			if (tmp2)
				tmp2[0] = '\0';
			memmove(out_name, tmp, strlen(tmp) + 1);
			tmp = out_name;
			goto extract_tag;
		}
	}

	if (prefixMatch(ROMS_PATH, tmp)) {
		tmp += strlen(ROMS_PATH) + 1;
		char* tmp2 = strchr(tmp, '/');
		if (tmp2)
			tmp2[0] = '\0';
		memmove(out_name, tmp, strlen(tmp) + 1);
		tmp = out_name;
	}

extract_tag:
	tmp = strrchr(tmp, '(');
	if (tmp) {
		tmp += 1;
		memmove(out_name, tmp, strlen(tmp) + 1);
		tmp = strchr(out_name, ')');
		if (tmp)
			tmp[0] = '\0';
	}
}

int libraryFindConsole(int i, const char *tag, char *out, size_t n)
{
	char roms[MAX_PATH];
	DIR *dh;
	struct dirent *dp;
	char full[MAX_PATH];
	char emu[MAX_PATH];

	if (!tag || !tag[0] || !out || n == 0)
		return 0;
	if (!libraryRomsDir(i, roms, sizeof(roms)))
		return 0;
	dh = opendir(roms);
	if (!dh)
		return 0;
	while ((dp = readdir(dh)) != NULL) {
		if (hide(dp->d_name))
			continue;
		snprintf(full, sizeof(full), "%s/%s", roms, dp->d_name);
		getEmuName(dp->d_name, emu);
		if (exactMatch(emu, (char *)tag)) {
			snprintf(out, n, "%s", full);
			closedir(dh);
			return 1;
		}
	}
	closedir(dh);
	return 0;
}
void getEmuPath(char* emu_name, char* pak_path) {
	sprintf(pak_path, "%s/Emus/%s/%s.pak/launch.sh", SDCARD_PATH, PLATFORM, emu_name);
	if (exists(pak_path)) return;
	sprintf(pak_path, "%s/Emus/%s.pak/launch.sh", PAKS_PATH, emu_name);
	if (exists(pak_path)) return;
	/* zlyme10 bound emu paks at paks/*.pak (no Emus/ folder). */
	sprintf(pak_path, "%s/%s.pak/launch.sh", PAKS_PATH, emu_name);
}

void normalizeNewline(char* line) {
	int len = strlen(line);
	if (len>1 && line[len-1]=='\n' && line[len-2]=='\r') { // windows!
		line[len-2] = '\n';
		line[len-1] = '\0';
	}
}
void trimTrailingNewlines(char* line) {
	int len = strlen(line);
	while (len>0 && line[len-1]=='\n') {
		line[len-1] = '\0'; // trim newline
		len -= 1;
	}
}
void trimSortingMeta(char** str) { // eg. `001) `
	// TODO: this code is suss
	char* safe = *str;
	while(isdigit(**str)) *str += 1; // ignore leading numbers

	if (*str[0]==')') { // then match a closing parenthesis
		*str += 1;
	}
	else { //  or bail, restoring the string to its original value
		*str = safe;
		return;
	}
	
	while(isblank(**str)) *str += 1; // ignore leading space
}

///////////////////////////////////////

int exists(char* path) {
	return access(path, F_OK)==0;
}
void touch(char* path) {
	close(open(path, O_RDWR|O_CREAT, 0777));
}
int toggle(char *path) {
    if (access(path, F_OK) == 0) {
        unlink(path);
        return 0;
    } else {
        touch(path);
        return 1;
    }
}
void putFile(char* path, char* contents) {
	FILE* file = fopen(path, "w");
	if (file) {
		fputs(contents, file);
		fclose(file);
	}
}
void getFile(char* path, char* buffer, size_t buffer_size) {
	FILE *file = fopen(path, "r");
	if (file) {
		fseek(file, 0L, SEEK_END);
		size_t size = ftell(file);
		if (size>buffer_size-1) size = buffer_size - 1;
		rewind(file);
		fread(buffer, sizeof(char), size, file);
		fclose(file);
		buffer[size] = '\0';
	}
}
char* allocFile(char* path) { // caller must free!
	char* contents = NULL;
	FILE *file = fopen(path, "r");
	if (file) {
		fseek(file, 0L, SEEK_END);
		size_t size = ftell(file);
		contents = calloc(size+1, sizeof(char));
		fseek(file, 0L, SEEK_SET);
		fread(contents, sizeof(char), size, file);
		fclose(file);
		contents[size] = '\0';
	}
	return contents;
}
int getInt(char* path) {
	int i = 0;
    if(path == NULL)
        return i;
    
	FILE *file = fopen(path, "r");
	if (file!=NULL) {
		int res = fscanf(file, "%i", &i);
		fclose(file);
        if(res != 1)
            i = 0; // failed to parse int
	}
	return i;
}
void putInt(char* path, int value) {
	char buffer[8];
	sprintf(buffer, "%d", value);
	putFile(path, buffer);
}

uint64_t getMicroseconds(void) {
    uint64_t ret;
    struct timeval tv;

    gettimeofday(&tv, NULL);

    ret = (uint64_t)tv.tv_sec * 1000000;
    ret += (uint64_t)tv.tv_usec;

    return ret;
}

#define max(a,b)             \
({                           \
    __typeof__ (a) _a = (a); \
    __typeof__ (b) _b = (b); \
    _a > _b ? _a : _b;       \
})

#define min(a,b)             \
({                           \
    __typeof__ (a) _a = (a); \
    __typeof__ (b) _b = (b); \
    _a < _b ? _a : _b;       \
})

int clamp(int x, int lower, int upper)
{
    return min(upper, max(x, lower));
}

double clampd(double x, double lower, double upper)
{
    return min(upper, max(x, lower));
}

char* findFileInDir(const char *directory, const char *filename) {
    char *filename_copy = strdup(filename);
    if (!filename_copy) {
        perror("strdup");
        return NULL;
    }

    // Strip extension from filename
    char *dot_pos = strrchr(filename_copy, '.');
    if (dot_pos) {
        *dot_pos = '\0';
    }

    DIR *dir = opendir(directory);
    if (!dir) {
        perror("opendir");
        free(filename_copy);
        return NULL;
    }

    struct dirent *entry;
    char *full_path = NULL;

    // Track the best (shortest) match to avoid prefix collisions.
    // e.g., searching for "Advance Wars" should match "Advance Wars (USA).gba"
    // over "Advance Wars 2 - Black Hole Rising (USA).gba"
    char *best_match_name = NULL;
    size_t best_match_len = SIZE_MAX;

    while ((entry = readdir(dir)) != NULL) {
        // Strip extension from entry for comparison
        char *entry_base = strdup(entry->d_name);
        if (!entry_base) continue;

        char *entry_dot = strrchr(entry_base, '.');
        if (entry_dot) *entry_dot = '\0';

        if (strstr(entry_base, filename_copy) == entry_base) {
            // Prefer shorter matches (closer to exact match)
            size_t entry_len = strlen(entry_base);
            if (entry_len < best_match_len) {
                free(best_match_name);
                best_match_name = strdup(entry->d_name);
                best_match_len = entry_len;
            }
        }
        free(entry_base);
    }

    closedir(dir);

    if (best_match_name) {
        full_path = (char *)malloc(strlen(directory) + strlen(best_match_name) + 2);
        if (full_path) {
            snprintf(full_path, strlen(directory) + strlen(best_match_name) + 2, "%s/%s", directory, best_match_name);
        }
        free(best_match_name);
    }

    free(filename_copy);
    return full_path;
}

int runCmdTimeout(const char *cmd, char *output, size_t output_len, int timeout_ms)
{
	int pipefd[2];
	pid_t pid;
	struct timespec start, now;
	int status = 0;
	int done = 0;
	size_t total = 0;

	if (!cmd || timeout_ms <= 0)
		return -1;
	if (pipe(pipefd) < 0)
		return -1;

	pid = fork();
	if (pid < 0) {
		close(pipefd[0]);
		close(pipefd[1]);
		return -1;
	}
	if (pid == 0) {
		setpgid(0, 0);
		close(pipefd[0]);
		dup2(pipefd[1], STDOUT_FILENO);
		dup2(pipefd[1], STDERR_FILENO);
		close(pipefd[1]);
		execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	}

	close(pipefd[1]);
	setpgid(pid, pid);
	if (output && output_len)
		output[0] = '\0';

	clock_gettime(CLOCK_MONOTONIC, &start);
	while (1) {
		int elapsed, remain;
		struct pollfd pfd = { .fd = pipefd[0], .events = POLLIN };
		pid_t waited;

		clock_gettime(CLOCK_MONOTONIC, &now);
		elapsed = (int)((now.tv_sec - start.tv_sec) * 1000L +
			(now.tv_nsec - start.tv_nsec) / 1000000L);
		remain = timeout_ms - elapsed;
		if (remain <= 0)
			break;

		if (poll(&pfd, 1, remain > 50 ? 50 : remain) > 0 &&
		    (pfd.revents & POLLIN)) {
			char buf[256];
			ssize_t n = read(pipefd[0], buf, sizeof buf);
			if (n > 0 && output && output_len > 1) {
				size_t room = output_len - 1 - total;
				size_t cpy = (size_t)n < room ? (size_t)n : room;
				memcpy(output + total, buf, cpy);
				total += cpy;
				output[total] = '\0';
			}
		}

		waited = waitpid(pid, &status, WNOHANG);
		if (waited == pid) {
			done = 1;
			break;
		}
	}

	close(pipefd[0]);
	if (!done) {
		kill(-pid, SIGKILL);
		waitpid(pid, &status, 0);
		return 124;
	}
	if (WIFEXITED(status))
		return WEXITSTATUS(status);
	return -1;
}
