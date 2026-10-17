#include "hdmi-mode.h"

#include <stdio.h>
#include <string.h>

static int failed;

static void expect(int cond, const char *msg)
{
	if (!cond) {
		fprintf(stderr, "hdmi-mode: %s\n", msg);
		failed = 1;
	}
}

static struct zlyme_hdmi_mode mode(int w, int h, int mhz, int preferred)
{
	struct zlyme_hdmi_mode m;

	m.width = w;
	m.height = h;
	m.refresh_mhz = mhz;
	m.preferred = preferred;
	return m;
}

int main(void)
{
	struct zlyme_hdmi_choice choice;
	struct zlyme_hdmi_choice active;
	struct zlyme_hdmi_choice again;
	struct zlyme_hdmi_mode list[4];

	zlyme_hdmi_choose(NULL, 0, &choice);
	expect(!choice.chosen, "disconnected list chose a mode");

	list[0] = mode(0, 720, 60000, 1);
	list[1] = mode(1920, 0, 60000, 0);
	list[2] = mode(1280, 720, 0, 1);
	zlyme_hdmi_choose(list, 3, &choice);
	expect(!choice.chosen, "incomplete EDID chose a mode");

	list[0] = mode(1920, 1080, 60000, 1);
	list[1] = mode(1280, 720, 60000, 0);
	list[2] = mode(640, 480, 60000, 0);
	zlyme_hdmi_choose(list, 3, &choice);
	expect(choice.chosen && choice.width == 1280 && choice.height == 720 &&
		       choice.refresh_mhz == 60000,
	       "720p60 lost to the preferred 1080p mode");

	list[0] = mode(1280, 720, 50000, 1);
	list[1] = mode(1920, 1080, 60000, 0);
	zlyme_hdmi_choose(list, 2, &choice);
	expect(choice.chosen && choice.width == 1280 && choice.height == 720 &&
		       choice.refresh_mhz == 50000,
	       "720p at 50 Hz was not kept when it is the preferred mode");

	list[0] = mode(1920, 1080, 60000, 1);
	list[1] = mode(1280, 720, 50000, 0);
	zlyme_hdmi_choose(list, 2, &choice);
	expect(choice.chosen && choice.width == 1920 && choice.height == 1080,
	       "preferred mode was skipped when 720p60 is absent");

	list[0] = mode(1920, 1080, 30000, 0);
	list[1] = mode(800, 600, 60000, 0);
	zlyme_hdmi_choose(list, 2, &choice);
	expect(choice.chosen && choice.width == 1920 && choice.height == 1080,
	       "first usable mode was skipped");

	list[0] = mode(1280, 720, 59940, 0);
	list[1] = mode(1280, 720, 60000, 0);
	zlyme_hdmi_choose(list, 2, &choice);
	expect(choice.refresh_mhz == 60000, "59.94 Hz beat an exact 60 Hz");

	list[0] = mode(1280, 720, 59000, 1);
	zlyme_hdmi_choose(list, 1, &choice);
	expect(choice.refresh_mhz == 59000, "59 Hz was treated as 60 Hz");

	memset(&active, 0, sizeof(active));
	list[0] = mode(1280, 720, 60000, 1);
	zlyme_hdmi_choose(list, 1, &choice);
	expect(zlyme_hdmi_needs_modeset(&active, &choice), "first 720p60 did not request a modeset");
	if (zlyme_hdmi_needs_modeset(&active, &choice))
		active = choice;
	zlyme_hdmi_choose(list, 1, &again);
	expect(!zlyme_hdmi_needs_modeset(&active, &again), "unchanged 720p60 requested another modeset");
	zlyme_hdmi_choose(NULL, 0, &again);
	expect(!zlyme_hdmi_needs_modeset(&active, &again), "disconnect requested a modeset");
	expect(active.width == 1280 && active.refresh_mhz == 60000,
	       "disconnect cleared the last good mode");
	list[0] = mode(1920, 1080, 60000, 1);
	zlyme_hdmi_choose(list, 1, &again);
	expect(zlyme_hdmi_needs_modeset(&active, &again), "a new mode did not request a modeset");
	if (0 && zlyme_hdmi_needs_modeset(&active, &again))
		active = again;
	expect(active.width == 1280, "a failed modeset replaced the active mode");

	expect(zlyme_panel_refresh_hz("40") == 40, "40 Hz panel refresh");
	expect(zlyme_panel_refresh_hz("50") == 50, "50 Hz panel refresh");
	expect(zlyme_panel_refresh_hz("60") == 60, "60 Hz panel refresh");
	expect(zlyme_panel_refresh_hz("30") == 60, "unknown panel refresh");
	expect(zlyme_panel_refresh_hz(NULL) == 60, "missing panel refresh");

	if (failed)
		return 1;
	printf("hdmi mode ok\n");
	return 0;
}
