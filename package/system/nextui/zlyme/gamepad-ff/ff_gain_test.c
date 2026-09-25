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
	expect(ff_effective_gain_percent(0) == 0, "eff 0");
	expect(ff_effective_gain_percent(10) == 15, "eff 10");
	expect(ff_effective_gain_percent(20) == 24, "eff 20");
	expect(ff_effective_gain_percent(50) == 53, "eff 50");
	expect(ff_effective_gain_percent(90) == 91, "eff 90");
	expect(ff_effective_gain_percent(100) == 100, "eff 100");
	expect(ff_gain_value(0) == 0, "gain 0");
	expect(ff_gain_value(100) == 0xffff, "gain 100");
	expect(ff_gain_value(10) == (int)(0xffffu * 15u / 100u), "gain 10");
	expect(ff_gain_value(101) < 0 && ff_gain_value(-1) < 0, "gain range");
	{
		int prev = -1;
		int u;

		for (u = 0; u <= 100; u++) {
			int v = ff_gain_value(u);

			expect(v >= 0 && v <= 0xffff, "bounded");
			expect(v >= prev, "monotonic");
			prev = v;
		}
	}
	expect(ff_motor_level(80, 10) == 80, "strong");
	expect(ff_motor_level(0, 10) == 10, "weak");
	expect(ff_motor_level(0, 0) == 0, "off");
	return fail;
}
