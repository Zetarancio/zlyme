#ifndef ZLYME_HDMI_MODE_H
#define ZLYME_HDMI_MODE_H

/* refresh_mhz is millihertz. 60 Hz is 60000. 59.94 Hz is 59940.
 * vrefresh is the kernel's integer field. SDL cannot tell 59.94 from 60. */
struct zlyme_hdmi_mode {
	int width;
	int height;
	int refresh_mhz;
	int vrefresh;
	int preferred;
};

struct zlyme_hdmi_choice {
	int width;
	int height;
	int refresh_mhz;
	int chosen;
};

struct zlyme_hdmi_rect {
	int x;
	int y;
	int w;
	int h;
};

/* One DRM connector. monitor_index matches RetroArch's 1-based count of
 * connected connectors that advertise modes, on this card only. */
struct zlyme_hdmi_connector {
	int card;
	int connector_id;
	int hdmia;
	int connected;
	int monitor_index;
	const char *name;
	const struct zlyme_hdmi_mode *modes;
	int count;
};

struct zlyme_hdmi_output {
	struct zlyme_hdmi_choice choice;
	int card;
	int connector_id;
	int monitor_index;
	int vrefresh;
	int mode_index;
	char name[32];
};

/* 1 when this client should program the policy's DRM mode.
 * A window that is not fullscreen takes the policy mode for its first
 * surface. A fullscreen request for the policy size, or for the desktop
 * mode entry, takes that same mode so the clock is the one zlyme-hdmi
 * chose. Any other fullscreen size is the application's request.
 * A Vulkan window is left alone. */
int zlyme_hdmi_apply_policy(int vulkan, int fullscreen, int matches_desktop,
			    int matches_policy_size);

/* clock_khz is the DRM mode clock. 0 when the timing is incomplete. */
int zlyme_hdmi_refresh_mhz(int clock_khz, int htotal, int vtotal);

void zlyme_hdmi_choose(const struct zlyme_hdmi_mode *modes, int count,
		       struct zlyme_hdmi_choice *out);

/* Separate connector lists. The list that can show 720p near 60 Hz wins.
 * Lists are not merged. */
int zlyme_hdmi_select_list(const struct zlyme_hdmi_mode *const *lists,
			   const int *counts, int nlists,
			   struct zlyme_hdmi_choice *out);

/* HDMI-A connectors only. Two connectors with the same size stay distinct:
 * the result names the connector id, not a resolution. */
int zlyme_hdmi_pick(const struct zlyme_hdmi_connector *cons, int n,
		    struct zlyme_hdmi_output *out);

int zlyme_hdmi_same(const struct zlyme_hdmi_choice *a,
		    const struct zlyme_hdmi_choice *b);

/* modeset_ok == 0 leaves active unchanged and returns 0. */
int zlyme_hdmi_commit(int modeset_ok, const struct zlyme_hdmi_choice *next,
		      struct zlyme_hdmi_choice *active);

/* Center logical_w x logical_h inside the output, preserving aspect. */
void zlyme_hdmi_viewport(int logical_w, int logical_h, int out_w, int out_h,
			 struct zlyme_hdmi_rect *out);

int zlyme_panel_refresh_hz(const char *saved);

#endif
