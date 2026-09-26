#include "order.h"

#include <stdio.h>
#include <string.h>

static int expect(const char *title, const char **paths, const char **names, int n,
		  const char **want, int want_change)
{
	const char *dst[8];
	int i, changed;

	changed = zlyme_order_builtin_last(paths, names, n, "Miyoo Flip Gamepad", dst);
	if (changed != want_change) {
		fprintf(stderr, "%s: change %d want %d\n", title, changed, want_change);
		return 1;
	}
	for (i = 0; i < n; i++) {
		if (strcmp(dst[i], want[i]) != 0) {
			fprintf(stderr, "%s: slot %d got %s want %s\n", title, i, dst[i], want[i]);
			return 1;
		}
	}
	return 0;
}

int main(void)
{
	int failed = 0;
	const char *p0[] = {"b"};
	const char *n0[] = {"Miyoo Flip Gamepad"};
	const char *w0[] = {"b"};
	const char *p1[] = {"b", "e1"};
	const char *n1[] = {"Miyoo Flip Gamepad", "External Gamepad"};
	const char *w1[] = {"e1", "b"};
	const char *p2[] = {"e1", "b", "e2"};
	const char *n2[] = {"External Gamepad", "Miyoo Flip Gamepad", "External Gamepad"};
	const char *w2[] = {"e1", "e2", "b"};
	const char *p3[] = {"e1", "e2", "b"};
	const char *n3[] = {"External Gamepad", "External Gamepad", "Miyoo Flip Gamepad"};
	const char *w3[] = {"e1", "e2", "b"};
	const char *p4[] = {"e1", "e2"};
	const char *n4[] = {"External Gamepad", "External Gamepad"};
	const char *w4[] = {"e1", "e2"};

	failed += expect("alone", p0, n0, 1, w0, 0);
	failed += expect("builtin then one", p1, n1, 2, w1, 1);
	failed += expect("split externals", p2, n2, 3, w2, 1);
	failed += expect("already last", p3, n3, 3, w3, 0);
	failed += expect("externals only", p4, n4, 2, w4, 0);
	if (failed) {
		fprintf(stderr, "ORDER_FAIL %d\n", failed);
		return 1;
	}
	printf("ORDER_OK\n");
	return 0;
}
