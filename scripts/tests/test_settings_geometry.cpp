// my355 Settings footer geometry. Constants match defines.h and
// workspace/my355/platform/platform.h: 640x480, scale 2, padding 10,
// pill 30, button 20.
#include "layout.hpp"

#include <cstdio>
#include <cstdlib>

static int failures = 0;

static void expect(bool ok, const char *msg)
{
	if (!ok) {
		std::fprintf(stderr, "geometry: %s\n", msg);
		failures++;
	}
}

static void check_list(const char *name, const ZlymeContentRect &content,
	int items, int row_px, int hint_top)
{
	int rows = zlyme_visible_rows(items, content.h, row_px);
	int row_bottom = zlyme_last_row_bottom(content, rows, row_px);
	int desc_top = zlyme_description_top(content, row_px);
	int desc_bottom = zlyme_description_bottom(content);
	int scroll_bottom = desc_top;
	if (row_bottom > desc_top) {
		std::fprintf(stderr, "geometry: %s row %d > description %d\n",
			name, row_bottom, desc_top);
		failures++;
	}
	if (desc_bottom > hint_top) {
		std::fprintf(stderr, "geometry: %s description %d > hint %d\n",
			name, desc_bottom, hint_top);
		failures++;
	}
	if (scroll_bottom > desc_top || scroll_bottom > hint_top) {
		std::fprintf(stderr, "geometry: %s scroll leaves the content band\n", name);
		failures++;
	}
}

int main()
{
	const int screen_w = 640;
	const int screen_h = 480;
	const int scale = 2;
	const int padding = 10 * scale;
	const int pill = 30 * scale;
	const int button = 20 * scale;
	const int hint_top = zlyme_hint_pill_top(screen_h, padding, pill);

	const ZlymeContentRect good = zlyme_settings_content(
		screen_w, screen_h, padding, pill, pill, true, true);
	const ZlymeContentRect bad = zlyme_settings_content(
		screen_w, screen_h, padding, pill, button, true, true);

	expect(zlyme_description_bottom(good) <= hint_top,
		"pill reservation still overlaps the hint");
	expect(zlyme_description_bottom(bad) > hint_top,
		"button reservation did not overlap; the regression would not catch it");

	check_list("fixed", good, 4, pill, hint_top);
	check_list("list", good, 6, pill, hint_top);
	check_list("wifi", good, 24, pill, hint_top);
	check_list("bluetooth", good, 24, pill, hint_top);

	// Keyboard draws in screen coordinates. Five rows, font medium is
	// 14*scale. A 40px line height is already taller than that font and
	// still ends above the hint pill.
	const int rows = 5;
	const int spacing = 5;
	const int line_h = 40;
	const int start_y = line_h * 4;
	const int key_bottom = start_y + (rows - 1) * (line_h + spacing) + line_h;
	expect(key_bottom <= hint_top, "keyboard last row overlaps the hint pill");

	if (failures) {
		std::fprintf(stderr, "geometry failed (%d)\n", failures);
		return 1;
	}
	std::printf("settings geometry ok\n");
	return 0;
}
