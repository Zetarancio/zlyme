/* The background layer blends. Replacing a picture means clearing to
 * the theme color first. This is that pixel rule, without SDL.
 */
#include <stdio.h>
#include <string.h>

struct pix {
	unsigned char r, g, b, a;
};

static void over(struct pix *dst, struct pix src)
{
	unsigned inv = 255u - src.a;

	dst->r = (unsigned char)((src.r * src.a + dst->r * inv) / 255u);
	dst->g = (unsigned char)((src.g * src.a + dst->g * inv) / 255u);
	dst->b = (unsigned char)((src.b * src.a + dst->b * inv) / 255u);
	dst->a = (unsigned char)(src.a + dst->a * inv / 255u);
}

static void replace(struct pix *layer, struct pix theme, const struct pix *src, int n)
{
	int i;

	for (i = 0; i < n; i++)
		layer[i] = theme;
	for (i = 0; i < n; i++)
		over(&layer[i], src[i]);
}

static void blend_only(struct pix *layer, const struct pix *src, int n)
{
	int i;

	for (i = 0; i < n; i++)
		over(&layer[i], src[i]);
}

static int same(struct pix a, struct pix b)
{
	return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

int main(void)
{
	struct pix theme = { 16, 16, 18, 255 };
	struct pix clear = { 0, 0, 0, 0 };
	struct pix a[2] = {
		{ 220, 20, 20, 255 },
		{ 0, 0, 0, 0 },
	};
	struct pix b[2] = {
		{ 0, 0, 0, 0 },
		{ 20, 40, 220, 255 },
	};
	struct pix layer[2];
	struct pix stuck[2];
	int fails = 0;

	replace(layer, theme, a, 2);
	if (!same(layer[0], a[0]) || !same(layer[1], theme)) {
		fprintf(stderr, "A did not replace the theme\n");
		fails++;
	}
	replace(layer, theme, b, 2);
	if (!same(layer[0], theme)) {
		fprintf(stderr, "A stayed after B\n");
		fails++;
	}
	if (!same(layer[1], b[1])) {
		fprintf(stderr, "B was not drawn\n");
		fails++;
	}
	replace(layer, theme, a, 2);
	if (!same(layer[1], theme) || !same(layer[0], a[0])) {
		fprintf(stderr, "B stayed after returning to A\n");
		fails++;
	}
	replace(layer, theme, NULL, 0);
	/* A cleared background is the theme, with no picture. */
	layer[0] = theme;
	layer[1] = theme;
	if (!same(layer[0], theme) || !same(layer[1], theme)) {
		fprintf(stderr, "clear did not restore the theme\n");
		fails++;
	}

	/* The bug: blending B onto A leaves A's opaque pixel. */
	stuck[0] = theme;
	stuck[1] = theme;
	blend_only(stuck, a, 2);
	blend_only(stuck, b, 2);
	if (same(stuck[0], theme)) {
		fprintf(stderr, "the unfixed blend already dropped A\n");
		fails++;
	}
	(void)clear;
	if (fails)
		return 1;
	printf("background replace ok\n");
	return 0;
}
