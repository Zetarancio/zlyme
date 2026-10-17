#include "zlyme_textrow.h"

#include <stdio.h>

int main(void)
{
	struct {
		char buf[16];
		unsigned char guard;
	} row;
	char ask[64];
	char huge[400];
	size_t n;
	int i;
	int fails = 0;

	memset(huge, 'A', sizeof(huge));
	huge[sizeof(huge) - 1] = '\0';
	row.guard = 0x5a;
	n = zlyme_copy_text_row(row.buf, sizeof(row.buf), huge, 399);
	if (n != 15 || row.guard != 0x5a || strlen(row.buf) != 15) {
		fprintf(stderr, "long row overflowed or was not cut\n");
		fails++;
	}
	if (zlyme_copy_text_row(row.buf, sizeof(row.buf), "ok", 2) != 2 ||
	    strcmp(row.buf, "ok") != 0) {
		fprintf(stderr, "short row changed\n");
		fails++;
	}
	if (!zlyme_cleanup_ask(ask, sizeof(ask), "Reset %d standalone settings?", 9) ||
	    strcmp(ask, "Reset 9 standalone settings?") != 0) {
		fprintf(stderr, "count prompt: %s\n", ask);
		fails++;
	}
	if (zlyme_cleanup_ask(ask, sizeof(ask), "Reset %d standalone settings?", 0)) {
		fprintf(stderr, "zero count produced a prompt\n");
		fails++;
	}
	/* A path list does not fit, and is not an argument of the prompt. */
	for (i = 0; i < 40; i++)
		memcpy(huge + i * 8, "/storage", 8);
	if (strstr(ask, "/storage") != NULL) {
		fprintf(stderr, "prompt included a path\n");
		fails++;
	}
	if (fails)
		return 1;
	printf("text row ok\n");
	return 0;
}
