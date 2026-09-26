#include "pad_policy.h"

#include <stdio.h>

static int expect(const char *title, int got, int want)
{
	if (got == want)
		return 0;
	fprintf(stderr, "%s: got %d want %d\n", title, got, want);
	return 1;
}

int main(void)
{
	int failed = 0;

	failed += expect("pre-handoff", zlyme_allow_physical(0, 0), 1);
	failed += expect("post-handoff", zlyme_allow_physical(0, 1), 0);
	failed += expect("maintenance with external", zlyme_allow_physical(1, 1), 1);
	failed += expect("normal duplicate", zlyme_builtin_duplicate(0, 1, 1), 1);
	failed += expect("normal virtual only", zlyme_builtin_duplicate(0, 0, 1), 0);
	failed += expect("maintenance external ok", zlyme_builtin_duplicate(1, 1, 1), 0);
	failed += expect("controller guide", zlyme_accept_menu_event(1, 1), 0);
	failed += expect("raw guide", zlyme_accept_menu_event(0, 1), 1);
	failed += expect("raw other", zlyme_accept_menu_event(0, 0), 0);
	if (failed) {
		fprintf(stderr, "PAD_FAIL %d\n", failed);
		return 1;
	}
	printf("PAD_OK\n");
	return 0;
}
