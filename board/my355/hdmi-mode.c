#include "hdmi-mode.h"

#include <stdlib.h>
#include <string.h>

static int usable(const struct zlyme_hdmi_mode *mode)
{
	return mode->width > 0 && mode->height > 0 && mode->refresh_mhz > 0;
}

static int near_60(int refresh_mhz)
{
	int delta = refresh_mhz - 60000;

	if (delta < 0)
		delta = -delta;
	return delta <= 500;
}

static int is_720p60(const struct zlyme_hdmi_mode *mode)
{
	return usable(mode) && mode->width == 1280 && mode->height == 720 &&
	       near_60(mode->refresh_mhz);
}

void zlyme_hdmi_choose(const struct zlyme_hdmi_mode *modes, int count,
		       struct zlyme_hdmi_choice *out)
{
	int i;
	int best = -1;
	int best_delta = 0;

	out->width = 0;
	out->height = 0;
	out->refresh_mhz = 0;
	out->chosen = 0;
	if (!modes || count <= 0)
		return;

	for (i = 0; i < count; i++) {
		int delta;

		if (!is_720p60(&modes[i]))
			continue;
		delta = modes[i].refresh_mhz - 60000;
		if (delta < 0)
			delta = -delta;
		if (best < 0 || delta < best_delta ||
		    (delta == best_delta && modes[i].preferred &&
		     !modes[best].preferred)) {
			best = i;
			best_delta = delta;
		}
	}
	if (best < 0) {
		for (i = 0; i < count; i++) {
			if (usable(&modes[i]) && modes[i].preferred) {
				best = i;
				break;
			}
		}
	}
	if (best < 0) {
		for (i = 0; i < count; i++) {
			if (usable(&modes[i])) {
				best = i;
				break;
			}
		}
	}
	if (best < 0)
		return;
	out->width = modes[best].width;
	out->height = modes[best].height;
	out->refresh_mhz = modes[best].refresh_mhz;
	out->chosen = 1;
}

int zlyme_hdmi_same(const struct zlyme_hdmi_choice *a,
		    const struct zlyme_hdmi_choice *b)
{
	if (!a || !b)
		return 0;
	return a->chosen && b->chosen && a->width == b->width &&
	       a->height == b->height && a->refresh_mhz == b->refresh_mhz;
}

int zlyme_hdmi_needs_modeset(const struct zlyme_hdmi_choice *active,
			     const struct zlyme_hdmi_choice *next)
{
	if (!next || !next->chosen)
		return 0;
	if (zlyme_hdmi_same(active, next))
		return 0;
	return 1;
}

int zlyme_panel_refresh_hz(const char *saved)
{
	if (saved && (strcmp(saved, "40") == 0 || strcmp(saved, "50") == 0 ||
		      strcmp(saved, "60") == 0))
		return atoi(saved);
	return 60;
}
