#ifndef ZLYME_HDMI_MODE_H
#define ZLYME_HDMI_MODE_H

/* One EDID mode. refresh_mhz is millihertz: 60 Hz is 60000, 59.94 Hz is 59940. */
struct zlyme_hdmi_mode {
	int width;
	int height;
	int refresh_mhz;
	int preferred;
};

struct zlyme_hdmi_choice {
	int width;
	int height;
	int refresh_mhz;
	int chosen;
};

/* Prefer 1280x720 within 0.5 Hz of 60. Otherwise the first preferred mode.
 * Otherwise the first mode with a positive size and refresh. An empty or
 * unusable list leaves chosen at 0. This does not modeset. */
void zlyme_hdmi_choose(const struct zlyme_hdmi_mode *modes, int count,
		       struct zlyme_hdmi_choice *out);

int zlyme_hdmi_same(const struct zlyme_hdmi_choice *a,
		    const struct zlyme_hdmi_choice *b);

/* 1 when next is a different chosen mode. Disconnect and a repeat return 0. */
int zlyme_hdmi_needs_modeset(const struct zlyme_hdmi_choice *active,
			     const struct zlyme_hdmi_choice *next);

/* Saved panel refresh. 40, 50, and 60 stay. Anything else is 60. */
int zlyme_panel_refresh_hz(const char *saved);

#endif
