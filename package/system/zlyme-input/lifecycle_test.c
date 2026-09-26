#include "lifecycle.h"

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

	failed += expect("release early", zlyme_release_done(1, 1), 0);
	failed += expect("release composite only", zlyme_release_done(0, 1), 0);
	failed += expect("release done", zlyme_release_done(0, 0), 1);
	failed += expect("reclaim shell", zlyme_reclaim_done(1, 0), 0);
	failed += expect("reclaim ready", zlyme_reclaim_done(1, 1), 1);
	failed += expect("owner gone", zlyme_should_deactivate(0), 1);
	failed += expect("owner stays", zlyme_should_deactivate(1), 0);
	failed += expect("activate", zlyme_should_activate(1, 1), 1);
	failed += expect("owner without manager", zlyme_should_activate(1, 0), 0);
	failed += expect("no owner", zlyme_should_activate(0, 1), 0);
	if (failed) {
		fprintf(stderr, "LIFE_FAIL %d\n", failed);
		return 1;
	}
	printf("LIFE_OK\n");
	return 0;
}
