#include "zlymejoystick.hpp"

extern "C" {
#include "defines.h"
#include "api.h"
}
#include "cal_logic.h"

#include <cstdio>
#include <cstring>
#include <dirent.h>
#include <string>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

static SDL_Surface *g_screen;

void ZlymeJoystick_setScreen(SDL_Surface *screen)
{
	g_screen = screen;
}

static const char *kSys = "/sys/bus/serial/drivers/miyoo-flip-gamepad";
static const char *kDir = "/storage/.config/zlyme/miyoo-flip-gamepad";

static bool find_node(char *path, size_t len, const char *leaf)
{
	DIR *dir = opendir(kSys);
	if (!dir)
		return false;
	struct dirent *ent;
	while ((ent = readdir(dir)) != NULL) {
		int n;
		if (ent->d_name[0] == '.')
			continue;
		n = snprintf(path, len, "%s/%s/%s", kSys, ent->d_name, leaf);
		if (n > 0 && (size_t)n < len && access(path, R_OK) == 0) {
			closedir(dir);
			return true;
		}
	}
	closedir(dir);
	return false;
}

static bool read_raw(int *yl, int *xl, int *yr, int *xr)
{
	char path[512];
	char body[128];
	const char *err = NULL;
	FILE *f;
	size_t n;

	if (!find_node(path, sizeof(path), "raw_axes"))
		return false;
	f = fopen(path, "r");
	if (!f)
		return false;
	n = fread(body, 1, sizeof(body) - 1, f);
	body[n] = 0;
	fclose(f);
	return cal_parse_raw(body, yl, xl, yr, xr, &err) == 0;
}

static bool write_text(const char *leaf, const char *text)
{
	char path[512];
	FILE *f;

	if (!find_node(path, sizeof(path), leaf))
		return false;
	f = fopen(path, "w");
	if (!f)
		return false;
	if (fputs(text, f) < 0 || fclose(f) != 0)
		return false;
	return true;
}

static int read_pct(bool right)
{
	char path[512];
	FILE *f;
	int n = 0;

	if (!find_node(path, sizeof(path), right ? "deadzone_right" : "deadzone_left"))
		return 0;
	f = fopen(path, "r");
	if (!f)
		return 0;
	if (fscanf(f, "%d", &n) != 1)
		n = 0;
	fclose(f);
	return n;
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

static void fill_dot(SDL_Surface *s, int x, int y, int rad, Uint32 color)
{
	for (int dy = -rad; dy <= rad; dy++) {
		for (int dx = -rad; dx <= rad; dx++) {
			SDL_Rect r;
			if (dx * dx + dy * dy > rad * rad)
				continue;
			r.x = x + dx;
			r.y = y + dy;
			r.w = r.h = 1;
			SDL_FillRect(s, &r, color);
		}
	}
}

static void text_at(const char *msg, int x, int y)
{
	SDL_Surface *t = TTF_RenderUTF8_Blended(font.small, msg, COLOR_WHITE);
	if (!t)
		return;
	SDL_Rect dst = {x, y, t->w, t->h};
	SDL_BlitSurface(t, NULL, g_screen, &dst);
	SDL_FreeSurface(t);
}

static void hint_left(const char *button, const char *label)
{
	char *h[] = {(char *)button, (char *)label, NULL};
	GFX_blitButtonGroup(h, 0, g_screen, 0);
}

static void hint_right(const char *button, const char *label)
{
	char *h[] = {(char *)button, (char *)label, NULL};
	GFX_blitButtonGroup(h, 1, g_screen, 1);
}

static void frame_begin(void)
{
	GFX_startFrame();
	PAD_poll();
	GFX_clear(g_screen);
}

static bool unavailable(void)
{
	char path[512];
	if (find_node(path, sizeof(path), "raw_axes"))
		return false;
	while (g_screen) {
		frame_begin();
		text_at("Joystick driver is not available.", 24, 80);
		hint_left("B", "BACK");
		GFX_flip(g_screen);
		if (PAD_justPressed(BTN_B))
			return true;
	}
	return true;
}

static void screen_test(void)
{
	SDL_Joystick *joy;
	if (unavailable())
		return;
	joy = open_pad();
	while (g_screen) {
		int ax[4] = {0, 0, 0, 0};
		frame_begin();
		if (joy) {
			SDL_JoystickUpdate();
			for (int i = 0; i < 4; i++)
				ax[i] = SDL_JoystickGetAxis(joy, i);
		}
		text_at("Test Sticks", 24, 16);
		text_at("Final output", 24, 48);
		hint_left("B", "BACK");
		for (int s = 0; s < 2; s++) {
			int cx = s ? 460 : 180;
			int cy = 240;
			fill_dot(g_screen, cx, cy, 70, SDL_MapRGB(g_screen->format, 40, 40, 40));
			fill_dot(g_screen, cx, cy, 4, SDL_MapRGB(g_screen->format, 80, 80, 80));
			int px = cx + ax[s * 2] * 60 / 32767;
			int py = cy + ax[s * 2 + 1] * 60 / 32767;
			fill_dot(g_screen, px, py, 6, SDL_MapRGB(g_screen->format, 240, 240, 240));
		}
		GFX_flip(g_screen);
		if (PAD_justPressed(BTN_B))
			break;
	}
	if (joy)
		SDL_JoystickClose(joy);
}

static int scale_side(int delta, int span)
{
	if (delta <= CAL_DEADBAND)
		return 0;
	span -= CAL_DEADBAND;
	if (span <= 0)
		return 0;
	int out = (delta - CAL_DEADBAND) * 32767 / span;
	if (out > 32767)
		out = 32767;
	if (out < 0)
		out = 0;
	return out;
}

static void read_axis(bool right, int *xmin, int *xzero, int *xmax,
		      int *ymin, int *yzero, int *ymax)
{
	char path[512];
	char line[64];
	FILE *f;
	*xmin = *ymin = 0;
	*xzero = *yzero = 128;
	*xmax = *ymax = 255;
	if (!find_node(path, sizeof(path), right ? "calibration_right" : "calibration_left"))
		return;
	f = fopen(path, "r");
	if (!f)
		return;
	while (fgets(line, sizeof(line), f)) {
		int v;
		if (sscanf(line, "x_min=%d", &v) == 1)
			*xmin = v;
		else if (sscanf(line, "x_runtime_zero=%d", &v) == 1)
			*xzero = v;
		else if (sscanf(line, "x_max=%d", &v) == 1)
			*xmax = v;
		else if (sscanf(line, "y_min=%d", &v) == 1)
			*ymin = v;
		else if (sscanf(line, "y_runtime_zero=%d", &v) == 1)
			*yzero = v;
		else if (sscanf(line, "y_max=%d", &v) == 1)
			*ymax = v;
	}
	fclose(f);
}

static void viz_raw(int raw, int mn, int zero, int mx, int *out)
{
	if (raw >= zero)
		*out = scale_side(raw - zero, mx - zero);
	else
		*out = -scale_side(zero - raw, zero - mn);
}

static bool save_deadzone_file(int left, int right)
{
	char body[64];
	char tmp[512];
	int fd, n;
	snprintf(body, sizeof(body), "left=%d\nright=%d\n", left, right);
	mkdir("/storage/.config", 0755);
	mkdir("/storage/.config/zlyme", 0755);
	mkdir(kDir, 0755);
	n = snprintf(tmp, sizeof(tmp), "%s/deadzone.config.tmp", kDir);
	if (n < 0 || (size_t)n >= sizeof(tmp))
		return false;
	fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0)
		return false;
	if (write(fd, body, strlen(body)) != (ssize_t)strlen(body) || fsync(fd) != 0) {
		close(fd);
		unlink(tmp);
		return false;
	}
	if (close(fd) != 0) {
		unlink(tmp);
		return false;
	}
	n = snprintf(tmp, sizeof(tmp), "%s/deadzone.config.tmp", kDir);
	char finalp[512];
	snprintf(finalp, sizeof(finalp), "%s/deadzone.config", kDir);
	if (rename(tmp, finalp) != 0) {
		unlink(tmp);
		return false;
	}
	return true;
}

static void ack(const char *msg)
{
	for (;;) {
		GFX_startFrame();
		PAD_poll();
		if (PAD_justPressed(BTN_A)) {
			MenuList::hideOverlay();
			return;
		}
		MenuList::showOverlay(msg, OverlayDismissMode::DismissOnA);
		GFX_sync();
	}
}

static int saved_other(bool saving_right)
{
	FILE *f = fopen("/storage/.config/zlyme/miyoo-flip-gamepad/deadzone.config", "r");
	char body[256];
	size_t n;
	int left = 0, right = 0;

	if (!f)
		return 0;
	n = fread(body, 1, sizeof(body) - 1, f);
	body[n] = 0;
	fclose(f);
	cal_parse_deadzone(body, &left, &right);
	return saving_right ? left : right;
}

static void screen_tune(bool right)
{
	int start = read_pct(right);
	int pct = start;
	char attr[32];
	SDL_Joystick *joy;
	if (unavailable())
		return;
	snprintf(attr, sizeof(attr), "%s", right ? "deadzone_right" : "deadzone_left");
	joy = open_pad();
	while (g_screen) {
		int yl, xl, yr, xr;
		int rawx = 0, rawy = 0;
		int vx = 0, vy = 0;
		int fx = 0, fy = 0;
		char line[96];
		frame_begin();
		int xmin, xzero, xmax, ymin, yzero, ymax;
		read_axis(right, &xmin, &xzero, &xmax, &ymin, &yzero, &ymax);
		if (read_raw(&yl, &xl, &yr, &xr)) {
			rawx = right ? xr : xl;
			rawy = right ? yr : yl;
			viz_raw(rawx, xmin, xzero, xmax, &vx);
			viz_raw(rawy, ymin, yzero, ymax, &vy);
		}
		if (joy) {
			SDL_JoystickUpdate();
			fx = SDL_JoystickGetAxis(joy, right ? 2 : 0);
			fy = SDL_JoystickGetAxis(joy, right ? 3 : 1);
		}
		text_at(right ? "Tune Right Deadzone" : "Tune Left Deadzone", 24, 16);
		snprintf(line, sizeof(line), "%d%%", pct);
		text_at(line, 24, 48);
		hint_left("B", "CANCEL");
		hint_right("A", "SAVE");
		int cx = 320, cy = 250;
		int inner = 70 * pct / 100;
		fill_dot(g_screen, cx, cy, 80, SDL_MapRGB(g_screen->format, 30, 30, 30));
		if (inner > 0)
			fill_dot(g_screen, cx, cy, inner, SDL_MapRGB(g_screen->format, 70, 50, 20));
		fill_dot(g_screen, cx + vx * 70 / 32767, cy + vy * 70 / 32767, 5,
			 SDL_MapRGB(g_screen->format, 180, 180, 80));
		fill_dot(g_screen, cx + fx * 70 / 32767, cy + fy * 70 / 32767, 6,
			 SDL_MapRGB(g_screen->format, 240, 240, 240));
		GFX_flip(g_screen);
		if (PAD_justRepeated(BTN_DPAD_LEFT) && pct > 0) {
			char buf[16];
			snprintf(buf, sizeof(buf), "%d\n", pct - 1);
			if (write_text(attr, buf))
				pct--;
			else
				ack("Could not apply deadzone.");
		}
		if (PAD_justRepeated(BTN_DPAD_RIGHT) && pct < 30) {
			char buf[16];
			snprintf(buf, sizeof(buf), "%d\n", pct + 1);
			if (write_text(attr, buf))
				pct++;
			else
				ack("Could not apply deadzone.");
		}
		if (PAD_justPressed(BTN_A)) {
			char buf[16];
			int keep = saved_other(right);
			int L = right ? keep : pct;
			int R = right ? pct : keep;
			snprintf(buf, sizeof(buf), "%d\n", pct);
			if (!write_text(attr, buf)) {
				ack("Could not apply deadzone. Not saved.");
				continue;
			}
			if (!save_deadzone_file(L, R))
				ack("Applied for this boot but save failed.");
			else
				ack("Deadzone saved.");
			break;
		}
		if (PAD_justPressed(BTN_B)) {
			char buf[16];
			snprintf(buf, sizeof(buf), "%d\n", start);
			if (!write_text(attr, buf))
				ack("Could not restore the previous deadzone. It may stay changed until reboot.");
			break;
		}
	}
	if (joy)
		SDL_JoystickClose(joy);
}

static int apply_sysfs(const char *line, void *ud)
{
	return write_text((const char *)ud, line) ? 0 : -1;
}

static void screen_cal(bool right)
{
	cal_cap cap;
	int step = 0;
	int stable = 0;
	int xmin, xrun, xmax, ymin, yrun, ymax;
	if (unavailable())
		return;
	read_axis(right, &xmin, &xrun, &xmax, &ymin, &yrun, &ymax);
	cal_cap_reset(&cap);
	while (g_screen) {
		int yl, xl, yr, xr, x = 0, y = 0;
		char line[160];
		frame_begin();
		if (read_raw(&yl, &xl, &yr, &xr)) {
			cal_map_stick(right, yl, xl, yr, xr, &x, &y);
			if (step == 0)
				cal_cap_add_range(&cap, x, y);
			else if (!stable) {
				cal_cap_add_center(&cap, x, y);
				if (cap.zero_n >= CAL_CENTER_SAMPLES) {
					if (cal_center_window_stable(&cap))
						stable = 1;
					else
						cal_center_window_reset(&cap);
				}
			}
		}
		text_at(right ? "Calibrate Right" : "Calibrate Left", 24, 16);
		if (step == 0) {
			text_at("Rotate the stick fully", 24, 52);
			text_at("around the edge.", 24, 80);
		} else {
			text_at("Release the stick.", 24, 52);
			text_at("Leave it untouched.", 24, 80);
			text_at(stable ? "CENTER STABLE" : "CENTERING...", 24, 116);
		}
		snprintf(line, sizeof(line), "RAW   X %d   Y %d", x, y);
		text_at(line, 24, 156);
		snprintf(line, sizeof(line), "RANGE X %d-%d", cap.x_min, cap.x_max);
		text_at(line, 24, 188);
		snprintf(line, sizeof(line), "      Y %d-%d", cap.y_min, cap.y_max);
		text_at(line, 24, 216);
		{
			int vx = 0, vy = 0;
			viz_raw(x, xmin, xrun, xmax, &vx);
			viz_raw(y, ymin, yrun, ymax, &vy);
			fill_dot(g_screen, 430, 250, 78, SDL_MapRGB(g_screen->format, 40, 40, 40));
			fill_dot(g_screen, 430 + vx * 64 / 32767, 250 + vy * 64 / 32767, 7,
				 SDL_MapRGB(g_screen->format, 240, 240, 240));
		}
		hint_left("B", "CANCEL");
		if (step == 0)
			hint_right("A", "NEXT");
		else if (stable)
			hint_right("A", "SAVE");
		GFX_flip(g_screen);
		if (PAD_justPressed(BTN_B))
			break;
		if (PAD_justPressed(BTN_A)) {
			if (step == 0) {
				if (!cal_range_ready(&cap)) {
					ack("Move the stick farther.");
					continue;
				}
				step = 1;
				cal_center_window_reset(&cap);
				continue;
			}
			if (!stable)
				continue;
			{
				cal_cfg cfg;
				const char *err = NULL;
				char msg[160];
				char path[512];
				char leaf[32];
				int rc;
				if (cal_cap_finish(&cap, &cfg, &err)) {
					ack(err ? err : "Invalid");
					stable = 0;
					cal_center_window_reset(&cap);
					continue;
				}
				snprintf(leaf, sizeof(leaf), "%s",
					 right ? "calibration_right" : "calibration_left");
				snprintf(path, sizeof(path), "%s/%s", kDir,
					 right ? "joypad_right.config" : "joypad.config");
				mkdir("/storage/.config", 0755);
				mkdir("/storage/.config/zlyme", 0755);
				mkdir(kDir, 0755);
				rc = cal_commit(&cfg, apply_sysfs, leaf, path, msg, sizeof(msg));
				ack(msg);
				if (rc == 0)
					break;
			}
		}
	}
}

struct stick_view {
	int xmin, xsave, xrun, xmax;
	int ymin, ysave, yrun, ymax;
	char xsrc[16];
	char ysrc[16];
};

static void load_stick_view(bool right, struct stick_view *v)
{
	char path[512];
	char line[64];
	FILE *f;

	memset(v, 0, sizeof(*v));
	snprintf(v->xsrc, sizeof(v->xsrc), "?");
	snprintf(v->ysrc, sizeof(v->ysrc), "?");
	if (!find_node(path, sizeof(path), right ? "calibration_right" : "calibration_left"))
		return;
	f = fopen(path, "r");
	if (!f)
		return;
	while (fgets(line, sizeof(line), f)) {
		int n;
		char src[16];
		if (sscanf(line, "x_min=%d", &n) == 1)
			v->xmin = n;
		else if (sscanf(line, "x_saved_zero=%d", &n) == 1)
			v->xsave = n;
		else if (sscanf(line, "x_runtime_zero=%d", &n) == 1)
			v->xrun = n;
		else if (sscanf(line, "x_max=%d", &n) == 1)
			v->xmax = n;
		else if (sscanf(line, "x_source=%15s", src) == 1)
			snprintf(v->xsrc, sizeof(v->xsrc), "%s", src);
		else if (sscanf(line, "y_min=%d", &n) == 1)
			v->ymin = n;
		else if (sscanf(line, "y_saved_zero=%d", &n) == 1)
			v->ysave = n;
		else if (sscanf(line, "y_runtime_zero=%d", &n) == 1)
			v->yrun = n;
		else if (sscanf(line, "y_max=%d", &n) == 1)
			v->ymax = n;
		else if (sscanf(line, "y_source=%15s", src) == 1)
			snprintf(v->ysrc, sizeof(v->ysrc), "%s", src);
	}
	fclose(f);
}

static const char *file_state(const char *path, int deadzone)
{
	FILE *f;
	char body[512];
	size_t n;
	const char *err = NULL;
	cal_cfg cfg;
	int left, right;

	f = fopen(path, "r");
	if (!f)
		return "missing";
	n = fread(body, 1, sizeof(body) - 1, f);
	body[n] = 0;
	fclose(f);
	if (deadzone)
		return cal_parse_deadzone(body, &left, &right) == 0 ? "OK" : "invalid";
	return cal_parse(body, &cfg, &err) == 0 ? "OK" : "invalid";
}

static void screen_values(void)
{
	if (unavailable())
		return;
	SDL_Joystick *joy = open_pad();
	while (g_screen) {
		struct stick_view L, R;
		int yl = 0, xl = 0, yr = 0, xr = 0;
		char line[160];
		char lpath[128], rpath[128], dpath[128];
		frame_begin();
		load_stick_view(false, &L);
		load_stick_view(true, &R);
		read_raw(&yl, &xl, &yr, &xr);
		text_at("Values", 16, 12);
		text_at("min / saved / runtime / max", 16, 40);
		hint_left("B", "BACK");
		snprintf(line, sizeof(line), "L X %d/%d/%d/%d %s",
			 L.xmin, L.xsave, L.xrun, L.xmax, L.xsrc);
		text_at(line, 16, 80);
		snprintf(line, sizeof(line), "L Y %d/%d/%d/%d %s",
			 L.ymin, L.ysave, L.yrun, L.ymax, L.ysrc);
		text_at(line, 16, 112);
		snprintf(line, sizeof(line), "R X %d/%d/%d/%d %s",
			 R.xmin, R.xsave, R.xrun, R.xmax, R.xsrc);
		text_at(line, 16, 152);
		snprintf(line, sizeof(line), "R Y %d/%d/%d/%d %s",
			 R.ymin, R.ysave, R.yrun, R.ymax, R.ysrc);
		text_at(line, 16, 184);
		snprintf(line, sizeof(line), "DZ  L %d%%   R %d%%", read_pct(false), read_pct(true));
		text_at(line, 16, 232);
		snprintf(line, sizeof(line), "RAW L %d,%d   R %d,%d", xl, yl, xr, yr);
		text_at(line, 16, 272);
		if (joy) {
			SDL_JoystickUpdate();
			snprintf(line, sizeof(line), "OUT L %d,%d   R %d,%d",
				 SDL_JoystickGetAxis(joy, 0), SDL_JoystickGetAxis(joy, 1),
				 SDL_JoystickGetAxis(joy, 2), SDL_JoystickGetAxis(joy, 3));
			text_at(line, 16, 312);
		}
		snprintf(lpath, sizeof(lpath), "%s/joypad.config", kDir);
		snprintf(rpath, sizeof(rpath), "%s/joypad_right.config", kDir);
		snprintf(dpath, sizeof(dpath), "%s/deadzone.config", kDir);
		snprintf(line, sizeof(line), "CFG L %s  R %s  DZ %s",
			 file_state(lpath, 0), file_state(rpath, 0), file_state(dpath, 1));
		text_at(line, 16, 352);
		GFX_flip(g_screen);
		if (PAD_justPressed(BTN_B))
			break;
	}
	if (joy)
		SDL_JoystickClose(joy);
}

static InputReactionHint go_test(AbstractMenuItem &)
{
	screen_test();
	return NoOp;
}
static InputReactionHint go_left(AbstractMenuItem &)
{
	screen_cal(false);
	return NoOp;
}
static InputReactionHint go_right(AbstractMenuItem &)
{
	screen_cal(true);
	return NoOp;
}
static InputReactionHint go_dzl(AbstractMenuItem &)
{
	screen_tune(false);
	return NoOp;
}
static InputReactionHint go_dzr(AbstractMenuItem &)
{
	screen_tune(true);
	return NoOp;
}
static InputReactionHint go_values(AbstractMenuItem &)
{
	screen_values();
	return NoOp;
}

void Zlyme_appendJoystickItem(std::vector<AbstractMenuItem *> &items)
{
	if (strcmp(PLATFORM, "my355") != 0)
		return;
	std::vector<AbstractMenuItem *> sub = {
		new MenuItem{ListItemType::Button, "Test Sticks", "Final stick output.", go_test},
		new MenuItem{ListItemType::Button, "Calibrate Left", "Capture range, then center.", go_left},
		new MenuItem{ListItemType::Button, "Calibrate Right", "Capture range, then center.", go_right},
		new MenuItem{ListItemType::Button, "Tune Left Deadzone", "Live preview.", go_dzl},
		new MenuItem{ListItemType::Button, "Tune Right Deadzone", "Live preview.", go_dzr},
		new MenuItem{ListItemType::Button, "Values", "Raw, output, and saved state.", go_values},
	};
	items.push_back(new MenuItem{ListItemType::Generic, "Joysticks",
		"Calibration and deadzone.", {}, {}, nullptr, nullptr, DeferToSubmenu,
		new MenuList(MenuItemType::Fixed, "Joysticks", sub)});
}
