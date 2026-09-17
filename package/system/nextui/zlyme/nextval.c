/*
 * Dump NextUI minuisettings as JSON. Apostrophe and minui-list load
 * theme colors from this. Upstream lives in NextUI workspace/all/nextval.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"

int main(int argc, char *argv[])
{
	CFG_init(NULL, NULL);

	if (argc <= 1) {
		CFG_print();
		return 0;
	}
	if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
		printf("usage: nextval.elf [setting]\n");
		return 0;
	}
	if (argc == 2) {
		char setting_value[512];

		setting_value[0] = '\0';
		CFG_get(argv[1], setting_value);
		if (setting_value[0])
			printf("{\"%s\": %s}\n", argv[1], setting_value);
		else
			printf("{}\n");
		return 0;
	}
	fprintf(stderr, "Error: Invalid argument '%s'\n", argv[1]);
	return 1;
}
