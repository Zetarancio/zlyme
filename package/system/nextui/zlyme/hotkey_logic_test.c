#include "hotkey_logic.h"

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
	int menu = 0, start = 0, other_menu = 0, other_start = 0;
	int failed = 0;

	failed += expect("menu only", zlyme_hotkey_apply(&menu, &start, BTN_MODE, 1), 0);
	failed += expect("start only", zlyme_hotkey_apply(&other_menu, &other_start, BTN_START, 1), 0);
	failed += expect("pad A chord", menu && start, 0);
	failed += expect("pad B chord", other_menu && other_start, 0);

	zlyme_hotkey_reset(&menu, &start);
	zlyme_hotkey_reset(&other_menu, &other_start);
	failed += expect("start then idle", zlyme_hotkey_apply(&menu, &start, BTN_START, 1), 0);
	failed += expect("same controller", zlyme_hotkey_apply(&menu, &start, BTN_MODE, 1), 1);
	failed += expect("release start", zlyme_hotkey_apply(&menu, &start, BTN_START, 0), 0);
	failed += expect("release menu", zlyme_hotkey_apply(&menu, &start, BTN_MODE, 0), 0);

	zlyme_hotkey_apply(&menu, &start, BTN_MODE, 1);
	zlyme_hotkey_apply(&menu, &start, BTN_START, 1);
	zlyme_hotkey_reset(&menu, &start);
	failed += expect("reset menu", menu, 0);
	failed += expect("reset start", start, 0);
	failed += expect("after reset", zlyme_hotkey_apply(&menu, &start, BTN_START, 0), 0);

	if (failed) {
		fprintf(stderr, "HOTKEY_FAIL %d\n", failed);
		return 1;
	}
	printf("HOTKEY_OK\n");
	return 0;
}
