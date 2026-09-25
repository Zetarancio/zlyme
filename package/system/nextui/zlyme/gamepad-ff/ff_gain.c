#include "ff_gain.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>

int ff_parse_gain(const char *text, int *pct)
{
	const char *p = text ? text : "";
	int seen = 0, value = FF_DEFAULT_GAIN_PERCENT, bad = 0;

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
			value = FF_DEFAULT_GAIN_PERCENT;
			seen = 1;
			continue;
		}
		value = (int)v;
		seen = 1;
	}
	*pct = bad ? FF_DEFAULT_GAIN_PERCENT : value;
	return bad ? -1 : 0;
}

int ff_parse_percent_token(const char *text, int *pct)
{
	char *end;
	long v;

	if (!pct)
		return -1;
	if (!text || !*text)
		return -1;
	errno = 0;
	v = strtol(text, &end, 10);
	if (errno || end == text || *end || v < 0 || v > 100)
		return -1;
	*pct = (int)v;
	return 0;
}

int ff_effective_gain_percent(int user)
{
	int num, rounded;

	if (user < 0 || user > 100)
		return -1;
	if (user == 0)
		return 0;
	/* 15 + (user-10)*85/90, nearest integer. 10 -> 15, 100 -> 100. */
	num = (user - 10) * 85;
	if (num >= 0)
		rounded = (num + 45) / 90;
	else
		rounded = -(((-num) + 45) / 90);
	return 15 + rounded;
}

int ff_gain_value(int pct)
{
	int effective = ff_effective_gain_percent(pct);

	if (effective < 0)
		return -1;
	return (int)((unsigned)0xffff * (unsigned)effective / 100);
}

unsigned ff_motor_level(unsigned strong, unsigned weak)
{
	return strong ? strong : weak;
}
