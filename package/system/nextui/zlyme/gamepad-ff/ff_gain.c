#include "ff_gain.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>

int ff_parse_gain(const char *text, int *pct)
{
	const char *p = text ? text : "";
	int seen = 0, value = 100, bad = 0;

	if (!pct)
		return -1;
	while (*p) {
		const char *nl = strchr(p, '\n');
		char line[64];
		size_t n = nl ? (size_t)(nl - p) : strlen(p);
		char *eq, *end;
		long v;

		if (n >= sizeof(line)) {
			bad = 1;
			break;
		}
		memcpy(line, p, n);
		line[n] = 0;
		p = nl ? nl + 1 : p + n;
		if (line[0] == 0 || line[0] == '#')
			continue;
		eq = strchr(line, '=');
		if (!eq || strncmp(line, "gain=", 5) != 0) {
			bad = 1;
			continue;
		}
		errno = 0;
		v = strtol(eq + 1, &end, 10);
		if (seen || errno || end == eq + 1 || *end || v < 0 || v > 100) {
			bad = 1;
			value = 100;
			seen = 1;
			continue;
		}
		value = (int)v;
		seen = 1;
	}
	*pct = bad ? 100 : value;
	return bad ? -1 : 0;
}

int ff_gain_value(int pct)
{
	if (pct < 0 || pct > 100)
		return -1;
	return (int)((unsigned)0xffff * (unsigned)pct / 100);
}

unsigned ff_motor_level(unsigned strong, unsigned weak)
{
	return strong ? strong : weak;
}
