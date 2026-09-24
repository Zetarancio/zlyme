/*
 * Joystick Calibration for Zlyme.
 *
 * Workflow adapted from Joe's Calibrage:
 * Copyright (c) 2026 Kevin Vranken
 * https://github.com/Helaas/nextui-Joe-s-Calibrage-pak
 * 205f662c9ab7334229787e024e3556ee00272aad
 * MIT License
 *
 * Zlyme modifications, 2026: sysfs apply-then-persist, raw_axes samples,
 * no UART ownership. The diagnostic tracer is not read.
 */
#define AP_IMPLEMENTATION
#include "apostrophe.h"
#define AP_WIDGETS_IMPLEMENTATION
#include "apostrophe_widgets.h"

#include "cal_logic.h"

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#define CAL_DIR "/storage/.config/zlyme/miyoo-flip-gamepad"
#define SYS_BASE "/sys/bus/serial/drivers/miyoo-flip-gamepad"

static int find_raw(char *path, size_t len)
{
	DIR *dir;
	struct dirent *ent;

	dir = opendir(SYS_BASE);
	if (!dir)
		return -1;
	while ((ent = readdir(dir)) != NULL) {
		int n;

		if (ent->d_name[0] == '.')
			continue;
		n = snprintf(path, len, "%s/%s/raw_axes", SYS_BASE, ent->d_name);
		if (n < 0 || (size_t)n >= len)
			continue;
		if (access(path, R_OK) == 0) {
			closedir(dir);
			return 0;
		}
	}
	closedir(dir);
	return -1;
}

static int read_raw(const char *raw_axes, int *yl, int *xl, int *yr, int *xr)
{
	FILE *f;
	char body[128];
	const char *err = NULL;
	size_t n;

	f = fopen(raw_axes, "r");
	if (!f)
		return -1;
	n = fread(body, 1, sizeof(body) - 1, f);
	body[n] = 0;
	fclose(f);
	return cal_parse_raw(body, yl, xl, yr, xr, &err);
}

static SDL_Joystick *open_pad(void)
{
	int i, n;

	SDL_JoystickUpdate();
	n = SDL_NumJoysticks();
	for (i = 0; i < n; i++) {
		const char *name = SDL_JoystickNameForIndex(i);
		if (name && strstr(name, "Miyoo Flip Gamepad"))
			return SDL_JoystickOpen(i);
	}
	return NULL;
}

static int apply_sysfs(const char *line, void *ud)
{
	FILE *f = fopen((const char *)ud, "w");

	if (!f)
		return -1;
	if (fputs(line, f) < 0 || fclose(f) != 0)
		return -1;
	return 0;
}

static void message(const char *text, int error)
{
	ap_footer_item footer[] = {
		{ .button = AP_BTN_A, .label = "OK", .is_confirm = true },
	};
	ap_message_opts opts = {
		.message = text,
		.footer = footer,
		.footer_count = 1,
	};
	ap_confirm_result result = {0};

	(void)error;
	(void)ap_confirmation(&opts, &result);
}

static int confirm(const char *text)
{
	ap_footer_item footer[] = {
		{ .button = AP_BTN_B, .label = "Cancel" },
		{ .button = AP_BTN_A, .label = "Restore", .is_confirm = true },
	};
	ap_message_opts opts = {
		.message = text,
		.footer = footer,
		.footer_count = 2,
	};
	ap_confirm_result result = {0};

	return ap_confirmation(&opts, &result) == AP_OK && result.confirmed;
}

static void mkdir_cal(void)
{
	mkdir("/storage/.config", 0755);
	mkdir("/storage/.config/zlyme", 0755);
	mkdir(CAL_DIR, 0755);
}

static int stick_files(int right, char *attr, size_t attr_len,
		       char *path, size_t path_len)
{
	char raw[512];
	char *slash;
	int n;

	if (find_raw(raw, sizeof(raw)))
		return -1;
	n = snprintf(attr, attr_len, "%s", raw);
	if (n < 0 || (size_t)n >= attr_len)
		return -1;
	slash = strrchr(attr, '/');
	if (!slash)
		return -1;
	n = snprintf(slash + 1, attr_len - (size_t)(slash + 1 - attr), "%s",
		     right ? "calibration_right" : "calibration_left");
	if (n < 0)
		return -1;
	n = snprintf(path, path_len, "%s/%s", CAL_DIR,
		     right ? "joypad_right.config" : "joypad.config");
	return (n < 0 || (size_t)n >= path_len) ? -1 : 0;
}

static int burst_center(const char *raw, int right, cal_cap *cap)
{
	int i;

	for (i = 0; i < 12; i++) {
		int yl, xl, yr, xr;

		if (read_raw(raw, &yl, &xl, &yr, &xr) == 0) {
			int x, y;

			cal_map_stick(right, yl, xl, yr, xr, &x, &y);
			cal_cap_add_center(cap, x, y);
		}
		SDL_Delay(20);
	}
	return cap->zero_n;
}

static void calibrate(int right)
{
	char raw[512];
	char attr[512];
	char path[512];
	char status[160] = "Move the stick around the edge, then A.";
	cal_cap cap;
	int step = 0;
	SDL_Joystick *joy;

	if (find_raw(raw, sizeof(raw)) ||
	    stick_files(right, attr, sizeof(attr), path, sizeof(path))) {
		message("Missing driver/raw data", 1);
		return;
	}
	cal_cap_reset(&cap);
	joy = open_pad();

	for (;;) {
		ap_input_event ev;
		int yl, xl, yr, xr;
		int x = -1, y = -1;
		float nx = 0, ny = 0;

		if (read_raw(raw, &yl, &xl, &yr, &xr) == 0) {
			cal_map_stick(right, yl, xl, yr, xr, &x, &y);
			if (step == 0)
				cal_cap_add_range(&cap, x, y);
		}
		if (joy) {
			SDL_JoystickUpdate();
			nx = SDL_JoystickGetAxis(joy, right ? 2 : 0) / 32767.0f;
			ny = SDL_JoystickGetAxis(joy, right ? 3 : 1) / 32767.0f;
		}
		ap_clear_screen();
		ap_draw_screen_title(right ? "Calibrate Right" : "Calibrate Left", NULL);
		ap_draw_text_wrapped(ap_get_font(AP_FONT_TINY), status, 16, 48, 600,
				     ap_get_theme()->text, AP_ALIGN_LEFT);
		if (x >= 0) {
			char raws[96];
			snprintf(raws, sizeof(raws), "raw X=%d Y=%d   app %.2f %.2f",
				 x, y, nx, ny);
			ap_draw_text_wrapped(ap_get_font(AP_FONT_MICRO), raws, 16, 90, 600,
					     ap_get_theme()->hint, AP_ALIGN_LEFT);
		}
		ap_draw_circle(180, 220, 70, ap_get_theme()->background);
		ap_draw_circle(180 + (int)(nx * 50), 220 + (int)(ny * 50), 8,
			       ap_get_theme()->accent);
		{
			ap_footer_item footer[] = {
				{ .button = AP_BTN_B, .label = "Cancel" },
				{ .button = AP_BTN_A, .label = step == 0 ? "Center" : "Save",
				  .is_confirm = true },
			};
			ap_draw_footer(footer, 2);
		}
		ap_present();

		while (ap_poll_input(&ev)) {
			const char *err = NULL;
			cal_cfg cfg;
			char msg[160];
			int rc;

			if (!ev.pressed)
				continue;
			if (ev.button == AP_BTN_B)
				goto out;
			if (ev.button != AP_BTN_A)
				continue;
			if (step == 0) {
				if (cap.range_n < 20 ||
				    (cap.x_max - cap.x_min) <= CAL_DEADBAND ||
				    (cap.y_max - cap.y_min) <= CAL_DEADBAND) {
					snprintf(status, sizeof(status), "Insufficient movement");
					continue;
				}
				step = 1;
				snprintf(status, sizeof(status),
					 "Hold the stick still at center, then A.");
				continue;
			}
			burst_center(raw, right, &cap);
			if (cal_cap_finish(&cap, &cfg, &err)) {
				snprintf(status, sizeof(status), "%s",
					 err ? err : "Invalid");
				cap.zero_n = 0;
				cap.zx_sum = cap.zy_sum = 0;
				cap.zx_lo = cap.zy_lo = 255;
				cap.zx_hi = cap.zy_hi = 0;
				continue;
			}
			mkdir_cal();
			rc = cal_commit(&cfg, apply_sysfs, attr, path, msg, sizeof(msg));
			message(msg, rc != 0);
			goto out;
		}
		SDL_Delay(30);
	}
out:
	if (joy)
		SDL_JoystickClose(joy);
}

static void append(char *dst, size_t len, const char *src)
{
	size_t used = strlen(dst);
	if (used >= len)
		return;
	snprintf(dst + used, len - used, "%s", src);
}

static void show_values(void)
{
	char raw[512];
	char body[1400];
	char line[256];
	FILE *f;
	const char *files[2] = {
		CAL_DIR "/joypad.config",
		CAL_DIR "/joypad_right.config",
	};
	const char *labels[2] = { "Left file", "Right file" };
	int i;

	body[0] = 0;
	for (i = 0; i < 2; i++) {
		append(body, sizeof(body), labels[i]);
		append(body, sizeof(body), ": ");
		f = fopen(files[i], "r");
		if (!f) {
			append(body, sizeof(body), "(none)\n");
			continue;
		}
		while (fgets(line, sizeof(line), f))
			append(body, sizeof(body), line);
		fclose(f);
		append(body, sizeof(body), "\n");
	}
	if (find_raw(raw, sizeof(raw)) == 0 && (f = fopen(raw, "r"))) {
		append(body, sizeof(body), "raw_axes: ");
		while (fgets(line, sizeof(line), f))
			append(body, sizeof(body), line);
		fclose(f);
	} else {
		append(body, sizeof(body), "Missing driver/raw data\n");
	}
	message(body, 0);
}

static void restore_backup(int right)
{
	char attr[512];
	char path[512];
	char bak[560];
	char text[512];
	char msg[160];
	FILE *f;
	size_t n;
	cal_cfg cfg;
	const char *err = NULL;
	int rc;

	if (stick_files(right, attr, sizeof(attr), path, sizeof(path))) {
		message("Missing driver/raw data", 1);
		return;
	}
	snprintf(bak, sizeof(bak), "%s.bak", path);
	if (!confirm(right ? "Restore the first right-stick backup?"
			   : "Restore the first left-stick backup?"))
		return;
	f = fopen(bak, "r");
	if (!f) {
		message("No backup", 1);
		return;
	}
	n = fread(text, 1, sizeof(text) - 1, f);
	text[n] = 0;
	fclose(f);
	if (cal_parse(text, &cfg, &err)) {
		message(err ? err : "invalid field", 1);
		return;
	}
	mkdir_cal();
	rc = cal_commit(&cfg, apply_sysfs, attr, path, msg, sizeof(msg));
	message(msg, rc != 0);
}

static void about(void)
{
	message("Calibration UI/workflow based in part on Joe's Calibrage "
		"by Kevin Vranken (Helaas), used under the MIT License.", 0);
}

int main(void)
{
	ap_config cfg = {0};

	cfg.window_title = "Joystick Calibration";
	cfg.is_nextui = AP_PLATFORM_IS_DEVICE;
	cfg.cpu_speed = AP_CPU_SPEED_MENU;
	if (ap_init(&cfg) != AP_OK)
		return 1;

	for (;;) {
		ap_list_item items[] = {
			AP_LIST_ITEM("Calibrate Left", NULL),
			AP_LIST_ITEM("Calibrate Right", NULL),
			AP_LIST_ITEM("View Values", NULL),
			AP_LIST_ITEM("Restore Left Backup", NULL),
			AP_LIST_ITEM("Restore Right Backup", NULL),
			AP_LIST_ITEM("About", NULL),
		};
		ap_footer_item footer[] = {
			{ .button = AP_BTN_B, .label = "Quit" },
			{ .button = AP_BTN_A, .label = "Select", .is_confirm = true },
		};
		ap_list_opts opts = ap_list_default_opts("Joystick Calibration", items, 6);
		ap_list_result result = {0};

		opts.footer = footer;
		opts.footer_count = 2;
		if (ap_list(&opts, &result) != AP_OK || result.selected_index < 0)
			break;
		if (result.selected_index == 0)
			calibrate(0);
		else if (result.selected_index == 1)
			calibrate(1);
		else if (result.selected_index == 2)
			show_values();
		else if (result.selected_index == 3)
			restore_backup(0);
		else if (result.selected_index == 4)
			restore_backup(1);
		else
			about();
	}
	ap_quit();
	return 0;
}
