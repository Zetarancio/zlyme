#include "cal_logic.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int fail;

static void expect(int cond, const char *msg)
{
	if (!cond) {
		fprintf(stderr, "FAIL %s\n", msg);
		fail = 1;
	}
}

static int apply_ok(const char *line, void *ud)
{
	(void)line;
	return ud ? 0 : -1;
}

static int apply_no(const char *line, void *ud)
{
	(void)line;
	(void)ud;
	return -1;
}

int main(void)
{
	cal_cfg cfg = { .x_min = 2, .x_max = 223, .x_zero = 103,
			.y_min = 25, .y_max = 239, .y_zero = 139 };
	cal_cap cap;
	const char *err = NULL;
	char msg[128];
	char path[] = "/tmp/zlyme-cal-test.cfg";
	int i;

	expect(cal_cfg_ok(&cfg) == 0, "asymmetric ok");
	cfg.x_zero = 2;
	expect(cal_cfg_ok(&cfg) != 0, "center at min");
	cfg.x_zero = 223;
	expect(cal_cfg_ok(&cfg) != 0, "center at max");
	cfg.x_zero = 4;
	expect(cal_cfg_ok(&cfg) != 0, "side <= 2");
	cfg.x_zero = 300;
	expect(cal_cfg_ok(&cfg) != 0, "out of range");

	cal_cap_reset(&cap);
	for (i = 0; i < 10; i++)
		cal_cap_add_center(&cap, 100, 100);
	expect(cal_cap_finish(&cap, &cfg, &err) != 0, "no range");
	cal_cap_reset(&cap);
	for (i = 0; i < 25; i++)
		cal_cap_add_range(&cap, i < 12 ? 2 : 223, i < 12 ? 25 : 239);
	for (i = 0; i < 12; i++)
		cal_cap_add_center(&cap, 103 + (i == 11 ? 8 : 0), 139);
	expect(cal_center_window_stable(&cap) == 0, "unstable window");
	cal_center_window_reset(&cap);
	expect(cap.range_n == 25, "reset keeps range");
	expect(cap.zero_n == 0, "reset clears center");
	for (i = 0; i < 12; i++)
		cal_cap_add_center(&cap, 103, 139);
	expect(cal_center_window_stable(&cap) == 1, "stable window");
	expect(cal_cap_finish(&cap, &cfg, &err) == 0, "valid capture");
	cal_cap_reset(&cap);
	for (i = 0; i < 25; i++)
		cal_cap_add_range(&cap, i < 12 ? 10 : 49, i < 12 ? 10 : 49);
	expect(cal_range_ready(&cap) == 0, "span 39 rejected");
	cal_cap_reset(&cap);
	for (i = 0; i < 25; i++)
		cal_cap_add_range(&cap, i < 12 ? 10 : 50, i < 12 ? 10 : 50);
	expect(cal_range_ready(&cap) == 1, "span 40 accepted");

	unlink(path);
	expect(cal_commit(&cfg, apply_no, NULL, path, msg, sizeof(msg)) == 1,
	       "apply fail");
	expect(access(path, F_OK) != 0, "file untouched");
	expect(strstr(msg, "Calibration saved") == NULL, "apply fail text");
	expect(cal_commit(&cfg, apply_ok, (void *)1, path, msg, sizeof(msg)) == 0,
	       "saved");
	expect(strcmp(msg, "Calibration saved") == 0, "saved text");
	{
		FILE *f = fopen(path, "r");
		char got[256] = {0};
		char tmp[512];
		expect(f != NULL, "file opened");
		if (f) {
			size_t n = fread(got, 1, sizeof(got) - 1, f);
			got[n] = 0;
			fclose(f);
		}
		expect(strcmp(got,
			      "x_min=2\nx_max=223\ny_min=25\ny_max=239\n"
			      "x_zero=103\ny_zero=139\n") == 0,
		       "atomic format");
		snprintf(tmp, sizeof(tmp), "%s.tmp", path);
		expect(access(tmp, F_OK) != 0, "temp removed");
	}
	expect(cal_commit(&cfg, apply_ok, (void *)1,
			  "/tmp/zlyme-cal-missing/no/file.cfg",
			  msg, sizeof(msg)) == 2,
	       "save fail");
	expect(strstr(msg, "save failed") != NULL, "partial text");
	expect(strstr(msg, "Calibration saved") == NULL, "not full success");

	cfg.x_min = 0;
	cfg.x_zero = 3;
	cfg.x_max = 255;
	cfg.y_min = 0;
	cfg.y_zero = 128;
	cfg.y_max = 255;
	expect(cal_cfg_ok(&cfg) == 0, "0..255 bounds");
	cfg.x_zero = 2;
	expect(cal_cfg_ok(&cfg) != 0, "side length 2");

	{
		const char *err = NULL;
		const char *ok =
			"x_min=2\nx_max=223\ny_min=25\ny_max=239\n"
			"x_zero=103\ny_zero=139\n";
		expect(cal_parse(ok, &cfg, &err) == 0, "parse ok");
		expect(cal_parse("x_max=223\ny_min=25\ny_max=239\n"
				 "x_zero=103\ny_zero=139\n",
				 &cfg, &err) != 0 &&
		       err && strcmp(err, "missing field") == 0,
		       "missing field");
		expect(cal_parse("x_min=2\nx_min=3\nx_max=223\ny_min=25\n"
				 "y_max=239\nx_zero=103\ny_zero=139\n",
				 &cfg, &err) != 0 &&
		       err && strcmp(err, "duplicate field") == 0,
		       "duplicate field");
		expect(cal_parse("x_min=abc\nx_max=223\ny_min=25\ny_max=239\n"
				 "x_zero=103\ny_zero=139\n",
				 &cfg, &err) != 0 &&
		       err && strcmp(err, "invalid field") == 0,
		       "invalid field");
	}

	cal_cap_reset(&cap);
	for (i = 0; i < 25; i++)
		cal_cap_add_range(&cap, i < 12 ? 2 : 223, i < 12 ? 25 : 239);
	for (i = 0; i < 4; i++)
		cal_cap_add_center(&cap, 103, 139);
	expect(cal_cap_finish(&cap, &cfg, &err) != 0, "few center samples");

	{
		int yl, xl, yr, xr, x, y;
		const char *rerr = NULL;

		expect(cal_parse_raw("YL=25 XL=2 YR=49 XR=17\n",
				     &yl, &xl, &yr, &xr, &rerr) == 0,
		       "raw parse");
		cal_map_stick(0, yl, xl, yr, xr, &x, &y);
		expect(x == 2 && y == 25, "left map XL/YL");
		cal_map_stick(1, yl, xl, yr, xr, &x, &y);
		expect(x == 17 && y == 49, "right map XR/YR");
		expect(cal_parse_raw("XR=17 YR=49 XL=2 YL=25\n",
				     &yl, &xl, &yr, &xr, &rerr) == 0,
		       "raw key order");
		cal_map_stick(0, yl, xl, yr, xr, &x, &y);
		expect(x == 2 && y == 25, "order does not swap x/y");
		expect(cal_parse_raw("YL=25 XL=2 YR=49\n",
				     &yl, &xl, &yr, &xr, &rerr) != 0 &&
		       rerr && strcmp(rerr, "incomplete raw") == 0,
		       "incomplete raw");
		expect(cal_parse_raw("raw YL=1 XL=2 YR=3 XR=4\n",
				     &yl, &xl, &yr, &xr, &rerr) != 0,
		       "tracer line rejected");
		expect(cal_parse_raw("YL=256 XL=2 YR=49 XR=17\n",
				     &yl, &xl, &yr, &xr, &rerr) != 0,
		       "raw out of range");
	}

	{
		char bak[512];
		snprintf(bak, sizeof(bak), "%s.bak", path);
		expect(access(bak, F_OK) != 0, "no bak");
	}

	{
		int l = 9, r = 9;
		expect(cal_parse_deadzone("left=5\nright=7\n", &l, &r) == 0 &&
		       l == 5 && r == 7, "dz both");
		expect(cal_parse_deadzone("left=12\n", &l, &r) == 0 &&
		       l == 12 && r == 0, "dz right missing");
		expect(cal_parse_deadzone("right=30\n", &l, &r) == 0 &&
		       l == 0 && r == 30, "dz left missing");
		expect(cal_parse_deadzone("left=4\nright=99\n", &l, &r) != 0 &&
		       l == 4 && r == 0, "dz right >30");
		expect(cal_parse_deadzone("left=abc\nright=8\n", &l, &r) != 0 &&
		       l == 0 && r == 8, "dz left nonnumeric");
		expect(l >= 0 && l <= 30 && r >= 0 && r <= 30, "dz stays in range");
	}

	unlink(path);
	return fail;
}
