#include "zlyme_prefs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

static int fails;

static void expect(int cond, const char *msg)
{
	if (!cond) {
		fprintf(stderr, "prefs reload: %s\n", msg);
		fails++;
	}
}

static int contains(const char *path, const char *needle)
{
	FILE *f = fopen(path, "r");
	char buf[512];

	if (!f)
		return 0;
	while (fgets(buf, sizeof(buf), f)) {
		if (strstr(buf, needle)) {
			fclose(f);
			return 1;
		}
	}
	fclose(f);
	return 0;
}

int main(void)
{
	char dir[] = "/tmp/zlyme-prefs-reload-XXXXXX";
	char path[512];
	char gov[16];
	char emu[32];
	FILE *f;

	if (!mkdtemp(dir))
		return 1;
	snprintf(path, sizeof(path), "%s/zlyme-prefs.txt", dir);
	setenv("ZLYME_PREFS_FILE", path, 1);

	prefsSet("rom", "GB", "nested/keep.gb", "play", "gambatte");
	prefsSet("folder", "GB", "nested", "smart", "");
	expect(contains(path, "nested/keep.gb"), "rom row was not saved");
	expect(contains(path, "folder\tGB\tnested"), "folder row was not saved");

	f = fopen(path, "w");
	if (!f)
		return 1;
	fputs("folder\tGB\tnested\tsmart\t\n", f);
	fputs("tag\tGB\t\tauto\t\n", f);
	fclose(f);

	prefsGetExact("rom", "GB", "nested/keep.gb", gov, sizeof(gov), emu, sizeof(emu));
	expect(!gov[0] && !emu[0], "deleted rom stayed in memory");
	prefsGetExact("folder", "GB", "nested", gov, sizeof(gov), emu, sizeof(emu));
	expect(strcmp(gov, "smart") == 0, "folder row was dropped on reload");
	prefsGetExact("tag", "GB", "", gov, sizeof(gov), emu, sizeof(emu));
	expect(strcmp(gov, "auto") == 0, "system row was not reloaded");

	prefsSet("rom", "NES", "new.nes", "idle", "fceumm");
	expect(contains(path, "new.nes"), "new row was not saved");
	expect(contains(path, "folder\tGB\tnested"), "folder row was lost on the next save");
	expect(!contains(path, "keep.gb"), "deleted rom was written back");

	{
		FILE *in;
		FILE *out;
		char buf[8192];
		char tmp[512];
		char *hit;
		size_t n;

		in = fopen(path, "r");
		if (!in)
			return 1;
		n = fread(buf, 1, sizeof(buf), in);
		fclose(in);
		hit = NULL;
		if (n >= 4) {
			size_t i;
			for (i = 0; i + 4 <= n; i++) {
				if (memcmp(buf + i, "idle", 4) == 0) {
					hit = buf + i;
					break;
				}
			}
		}
		expect(hit != NULL, "same-size source has no idle field");
		if (hit)
			memcpy(hit, "fast", 4);
		snprintf(tmp, sizeof(tmp), "%s/swap.txt", dir);
		out = fopen(tmp, "w");
		if (!out)
			return 1;
		if (fwrite(buf, 1, n, out) != n) {
			fclose(out);
			return 1;
		}
		if (fclose(out) != 0)
			return 1;
		expect(rename(tmp, path) == 0, "same-size rename failed");
		prefsGetExact("rom", "NES", "new.nes", gov, sizeof(gov), emu, sizeof(emu));
		expect(strcmp(gov, "fast") == 0, "same-size rewrite stayed cached");
	}

	{
		FILE *big;
		int i;
		char line[64];
		big = fopen(path, "w");
		if (!big)
			return 1;
		for (i = 0; i < 257; i++) {
			snprintf(line, sizeof(line), "rom\tGB\tr%03d.gb\tplay\tm\n", i);
			fputs(line, big);
		}
		if (fclose(big) != 0)
			return 1;
		prefsSet("rom", "GB", "extra.gb", "idle", "gambatte");
		expect(contains(path, "r256.gb"), "overflow save dropped the last row");
		expect(!contains(path, "extra.gb"), "overflow save wrote a partial file");
		prefsGetExact("rom", "GB", "r000.gb", gov, sizeof(gov), emu, sizeof(emu));
		expect(strcmp(gov, "play") == 0, "a cached row failed lookup");
	}

	if (chmod(dir, 0555) != 0)
		return 1;
	prefsSet("rom", "GB", "should-not.gb", "heavy", "mgba");
	if (chmod(dir, 0755) != 0)
		return 1;
	expect(!contains(path, "should-not.gb"), "failed write changed the file");
	prefsGetExact("rom", "GB", "r000.gb", gov, sizeof(gov), emu, sizeof(emu));
	expect(strcmp(gov, "play") == 0, "failed write changed the cached row");

	unlink(path);
	rmdir(dir);
	if (fails)
		return 1;
	printf("prefs reload ok\n");
	return 0;
}
