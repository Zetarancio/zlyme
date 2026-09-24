/* Host mirror of mf_radial in miyoo-flip-gamepad.c. Not linked into the image. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define M 32767

static uint64_t isqrt(uint64_t n)
{
	uint64_t r = 0, bit = 1ULL << 62;

	while (bit > n)
		bit >>= 2;
	while (bit) {
		if (n >= r + bit) {
			n -= r + bit;
			r = (r >> 1) + bit;
		} else {
			r >>= 1;
		}
		bit >>= 2;
	}
	return r;
}

static void radial(int pct, int *x, int *y)
{
	int64_t xs, ys, num, den, d, r;
	int ox, oy;

	if (pct <= 0)
		return;
	xs = *x;
	ys = *y;
	if (xs == 0 && ys == 0)
		return;
	r = (int64_t)isqrt((uint64_t)(xs * xs + ys * ys));
	if (r == 0)
		return;
	d = (int64_t)M * pct / 100;
	if (r <= d) {
		*x = 0;
		*y = 0;
		return;
	}
	num = (r - d) * M;
	den = r * (M - d);
	ox = (int)(xs * num / den);
	oy = (int)(ys * num / den);
	if (ox > M)
		ox = M;
	if (ox < -M)
		ox = -M;
	if (oy > M)
		oy = M;
	if (oy < -M)
		oy = -M;
	*x = ox;
	*y = oy;
}

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
	int x, y, ox, oy;
	int pct;

	x = 1000;
	y = -2000;
	radial(0, &x, &y);
	expect(x == 1000 && y == -2000, "pct 0 unchanged");

	x = y = 0;
	radial(15, &x, &y);
	expect(x == 0 && y == 0, "center");

	for (pct = 1; pct <= 30; pct++) {
		int d = M * pct / 100;

		x = d;
		y = 0;
		radial(pct, &x, &y);
		expect(x == 0 && y == 0, "on boundary");
		x = d - 1;
		y = 0;
		radial(pct, &x, &y);
		expect(x == 0 && y == 0, "inside");
		x = d + 50;
		y = 0;
		radial(pct, &x, &y);
		expect(x > 0 && x < 2000, "just outside is small");
		x = M;
		y = 0;
		radial(pct, &x, &y);
		expect(x == M && y == 0, "+X full");
		x = -M;
		y = 0;
		radial(pct, &x, &y);
		expect(x == -M && y == 0, "-X full");
		x = 0;
		y = M;
		radial(pct, &x, &y);
		expect(x == 0 && y == M, "+Y full");
		x = 0;
		y = -M;
		radial(pct, &x, &y);
		expect(x == 0 && y == -M, "-Y full");
		x = 20000;
		y = 10000;
		ox = x;
		oy = y;
		radial(pct, &x, &y);
		expect(x <= M && y <= M && x >= -M && y >= -M, "clamped");
		expect(ox == 0 || (x > 0) == (ox > 0), "x sign");
		expect(oy == 0 || (y > 0) == (oy > 0), "y sign");
	}

	x = 20000;
	y = 10000;
	radial(10, &x, &y);
	expect(abs(x * 10000 - y * 20000) < 20000 * 50, "diagonal direction");
	return fail;
}
