#include "ff_gain.h"

#include <stdio.h>

static int fail;

static void expect(int cond, const char *msg)
{
	if (!cond) {
		fprintf(stderr, "FAIL %s\n", msg);
		fail = 1;
	}
}

int main(void)
{
	int pct = 0;

	expect(ff_parse_gain(NULL, &pct) == 0 && pct == 100, "missing");
	expect(ff_parse_gain("gain=0\n", &pct) == 0 && pct == 0, "zero");
	expect(ff_parse_gain("gain=100\n", &pct) == 0 && pct == 100, "full");
	expect(ff_parse_gain("gain=101\n", &pct) != 0 && pct == 100, "101");
	expect(ff_parse_gain("gain=-1\n", &pct) != 0 && pct == 100, "negative");
	expect(ff_parse_gain("gain=abc\n", &pct) != 0 && pct == 100, "junk");
	expect(ff_parse_gain("gain=10\ngain=20\n", &pct) != 0 && pct == 100, "dup");
	expect(ff_gain_value(0) == 0, "gain 0");
	expect(ff_gain_value(100) == 0xffff, "gain 100");
	expect(ff_gain_value(50) == 0x7fff, "gain 50");
	expect(ff_gain_value(101) < 0, "gain range");
	expect(ff_motor_level(80, 10) == 80, "strong");
	expect(ff_motor_level(0, 10) == 10, "weak");
	expect(ff_motor_level(0, 0) == 0, "off");
	return fail;
}
