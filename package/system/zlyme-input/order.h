#ifndef ZLYME_INPUT_ORDER_H
#define ZLYME_INPUT_ORDER_H

/* Reorder composite paths so every non-builtin entry keeps its relative
 * order and the builtin composite, if present, is last.
 * paths and names are parallel. dst receives n paths.
 * Returns 1 when dst differs from paths. */
int zlyme_order_builtin_last(const char *const *paths, const char *const *names,
			     int n, const char *builtin_name, const char **dst);

#endif
