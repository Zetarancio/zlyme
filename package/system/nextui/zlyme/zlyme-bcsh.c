/*
 * Re-apply VOP2 BCSH from msettings.bin. SDL/RetroArch modeset can drop
 * TV properties; ra-run and standalone paks call this after NextUI exits
 * (DRM master is free) and before the emulator opens the card.
 */
#include <stdlib.h>
#include <unistd.h>

#include "msettings.h"

int main(void)
{
	if (!getenv("USERDATA_PATH"))
		setenv("USERDATA_PATH", "/storage/.config/nextui/my355", 0);
	InitSettings();
	QuitSettings();
	return 0;
}
