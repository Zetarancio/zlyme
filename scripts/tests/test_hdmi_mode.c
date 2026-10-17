#include "hdmi_mode.h"

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

	memset(&m, 0, sizeof(m));
	m.width = w;
	m.height = h;
	m.refresh_mhz = mhz;
	m.vrefresh = (mhz + 500) / 1000;
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
	expect(zlyme_hdmi_commit(1, &choice, &active), "first 720p60 did not commit");
	zlyme_hdmi_choose(list, 1, &again);
	expect(!zlyme_hdmi_commit(1, &again, &active), "unchanged 720p60 committed again");
	zlyme_hdmi_choose(NULL, 0, &again);
	expect(!zlyme_hdmi_commit(1, &again, &active), "disconnect committed a mode");
	expect(active.width == 1280 && active.refresh_mhz == 60000,
	       "disconnect cleared the last good mode");
	list[0] = mode(1920, 1080, 60000, 1);
	zlyme_hdmi_choose(list, 1, &again);
	expect(!zlyme_hdmi_commit(0, &again, &active), "failed modeset reported success");
	expect(active.width == 1280 && active.refresh_mhz == 60000,
	       "failed modeset replaced the active mode");
	expect(zlyme_hdmi_commit(1, &again, &active), "successful modeset did not commit");
	expect(active.width == 1920, "successful modeset did not stick");
	expect(!zlyme_hdmi_commit(1, &again, &active), "repeat modeset was not a no-op");

	{
		struct zlyme_hdmi_mode panel[] = { mode(640, 480, 60000, 1) };
		struct zlyme_hdmi_mode hdmi[] = {
			mode(1920, 1080, 60000, 1),
			mode(1280, 720, 59940, 0)
		};
		const struct zlyme_hdmi_mode *lists[] = { panel, hdmi };
		int counts[] = { 1, 2 };
		int which = zlyme_hdmi_select_list(lists, counts, 2, &choice);

		expect(which == 1 && choice.width == 1280 && choice.refresh_mhz == 59940,
		       "panel list was preferred over HDMI 720p59.94");
	}
	expect(zlyme_hdmi_refresh_mhz(74176, 1650, 750) == 59940,
	       "74176 kHz 1650x750 is not 59.94 Hz");
	expect(zlyme_hdmi_refresh_mhz(74250, 1650, 750) == 60000,
	       "74250 kHz 1650x750 is not 60 Hz");
	expect(zlyme_hdmi_refresh_mhz(0, 1650, 750) == 0, "missing clock produced a refresh");

	{
		struct zlyme_hdmi_rect box;

		zlyme_hdmi_viewport(640, 480, 640, 480, &box);
		expect(box.x == 0 && box.y == 0 && box.w == 640 && box.h == 480,
		       "panel viewport is not the full 640x480");
		zlyme_hdmi_viewport(640, 480, 1280, 720, &box);
		expect(box.x == 160 && box.y == 0 && box.w == 960 && box.h == 720,
		       "720p viewport is not centered 960x720");
		zlyme_hdmi_viewport(640, 480, 1920, 1080, &box);
		expect(box.x == 240 && box.y == 0 && box.w == 1440 && box.h == 1080,
		       "1080p viewport is not centered 1440x1080");
	}

	expect(zlyme_panel_refresh_hz("40") == 40, "40 Hz panel refresh");
	expect(zlyme_panel_refresh_hz("50") == 50, "50 Hz panel refresh");
	expect(zlyme_panel_refresh_hz("60") == 60, "60 Hz panel refresh");
	expect(zlyme_panel_refresh_hz("30") == 60, "unknown panel refresh");
	expect(zlyme_panel_refresh_hz(NULL) == 60, "missing panel refresh");

	{
		struct zlyme_hdmi_mode dsi[] = { mode(1280, 720, 60000, 1) };
		struct zlyme_hdmi_mode hdmi[] = { mode(1280, 720, 59940, 0) };
		struct zlyme_hdmi_connector cons[2];
		struct zlyme_hdmi_output picked;

		memset(cons, 0, sizeof(cons));
		cons[0].card = 0;
		cons[0].connector_id = 179;
		cons[0].hdmia = 0;
		cons[0].connected = 1;
		cons[0].monitor_index = 1;
		cons[0].name = "DSI-1";
		cons[0].modes = dsi;
		cons[0].count = 1;
		cons[1].card = 0;
		cons[1].connector_id = 164;
		cons[1].hdmia = 1;
		cons[1].connected = 1;
		cons[1].monitor_index = 2;
		cons[1].name = "HDMI-A-1";
		cons[1].modes = hdmi;
		cons[1].count = 1;
		expect(zlyme_hdmi_pick(cons, 2, &picked) == 1, "same size picked the panel");
		expect(picked.connector_id == 164 && picked.monitor_index == 2,
		       "same size lost the HDMI connector id");
		expect(picked.choice.refresh_mhz == 59940, "same size lost 59.94 Hz");
		expect(zlyme_hdmi_pick(cons, 0, &picked) < 0, "empty connector list succeeded");
	}

	if (failed)
		return 1;
	printf("hdmi mode ok\n");
	return 0;
}
