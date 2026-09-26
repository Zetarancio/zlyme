#include "order.h"

#include <string.h>

int zlyme_order_builtin_last(const char *const *paths, const char *const *names,
			     int n, const char *builtin_name, const char **dst)
{
	int i, w = 0, changed = 0;

	for (i = 0; i < n; i++) {
		if (names[i] && strcmp(names[i], builtin_name) == 0)
			continue;
		dst[w++] = paths[i];
	}
	for (i = 0; i < n; i++) {
		if (names[i] && strcmp(names[i], builtin_name) == 0)
			dst[w++] = paths[i];
	}
	if (w != n)
		return 0;
	for (i = 0; i < n; i++) {
		if (dst[i] != paths[i])
			changed = 1;
	}
	return changed;
}
