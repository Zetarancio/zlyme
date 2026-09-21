/*
 * Re-apply VOP2 BCSH from msettings.bin. SDL/RetroArch modeset can drop
 * TV properties; ra-run and standalone paks call this after NextUI exits
 * (DRM master is free) and before the emulator opens the card.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "msettings.h"

/* NextUI stores per-platform state under this directory. The name is
 * ZLYME_NEXTUI_PLATFORM in the board metadata. my355 is the fallback
 * only when that file is absent (images built before device.conf). */
static void zlyme_set_userdata_path(void)
{
	FILE *f;
	char line[160];
	char plat[64];
	char path[160];
	char *p;
	size_t n;

	if (getenv("USERDATA_PATH"))
		return;
	plat[0] = '\0';
	f = fopen("/usr/share/zlyme/device.conf", "r");
	if (f) {
		while (fgets(line, sizeof(line), f)) {
			if (strncmp(line, "ZLYME_NEXTUI_PLATFORM=", 22) != 0)
				continue;
			p = line + 22;
			while (*p == ' ' || *p == '\t' || *p == '\'' || *p == '"')
				p++;
			n = strcspn(p, "\r\n'\"");
			if (n > 0 && n < sizeof(plat)) {
				memcpy(plat, p, n);
				plat[n] = '\0';
			}
			break;
		}
		fclose(f);
	}
	if (plat[0] == '\0')
		snprintf(plat, sizeof(plat), "my355");
	snprintf(path, sizeof(path), "/storage/.config/nextui/%s", plat);
	setenv("USERDATA_PATH", path, 0);
}

int main(void)
{
	zlyme_set_userdata_path();
	InitSettings();
	QuitSettings();
	return 0;
}
