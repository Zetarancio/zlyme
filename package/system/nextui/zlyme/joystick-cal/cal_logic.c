#include "cal_logic.h"

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int cal_center_ok(int min, int zero, int max)
{
	if (min < 0 || zero < 0 || max < 0 || min > 255 || zero > 255 || max > 255)
		return -1;
	if (!(min < zero && zero < max))
		return -1;
	if ((zero - min) <= CAL_DEADBAND || (max - zero) <= CAL_DEADBAND)
		return -1;
	return 0;
}

int cal_cfg_ok(const cal_cfg *cfg)
{
	if (!cfg)
		return -1;
	if (cal_center_ok(cfg->x_min, cfg->x_zero, cfg->x_max))
		return -1;
	if (cal_center_ok(cfg->y_min, cfg->y_zero, cfg->y_max))
		return -1;
	return 0;
}

static int field_set(int *slot, int *seen, int value)
{
	if (*seen)
		return -1;
	*slot = value;
	*seen = 1;
	return 0;
}

int cal_parse(const char *text, cal_cfg *cfg, const char **err)
{
	int seen[6] = {0};
	int vals[6] = {0};
	const char *p = text;
	static const char *keys[6] = {
		"x_min", "x_max", "y_min", "y_max", "x_zero", "y_zero"
	};

	if (!text || !cfg) {
		*err = "invalid field";
		return -1;
	}
	while (*p) {
		const char *nl;
		char line[64];
		size_t n;
		char *eq;
		char *end;
		long v;
		int i;

		nl = strchr(p, '\n');
		n = nl ? (size_t)(nl - p) : strlen(p);
		if (n >= sizeof(line)) {
			*err = "invalid field";
			return -1;
		}
		memcpy(line, p, n);
		line[n] = 0;
		p = nl ? nl + 1 : p + n;
		if (line[0] == 0 || line[0] == '#')
			continue;
		eq = strchr(line, '=');
		if (!eq || eq == line || eq[1] == 0) {
			*err = "invalid field";
			return -1;
		}
		*eq = 0;
		for (end = eq + 1; *end; end++) {
			if (!isdigit((unsigned char)*end)) {
				*err = "invalid field";
				return -1;
			}
		}
		errno = 0;
		v = strtol(eq + 1, &end, 10);
		if (errno || *end || v < 0 || v > 255) {
			*err = "invalid field";
			return -1;
		}
		for (i = 0; i < 6; i++) {
			if (strcmp(line, keys[i]) == 0)
				break;
		}
		if (i == 6) {
			*err = "invalid field";
			return -1;
		}
		if (field_set(&vals[i], &seen[i], (int)v)) {
			*err = "duplicate field";
			return -1;
		}
	}
	for (int i = 0; i < 6; i++) {
		if (!seen[i]) {
			*err = "missing field";
			return -1;
		}
	}
	cfg->x_min = vals[0];
	cfg->x_max = vals[1];
	cfg->y_min = vals[2];
	cfg->y_max = vals[3];
	cfg->x_zero = vals[4];
	cfg->y_zero = vals[5];
	if (cal_cfg_ok(cfg)) {
		*err = "invalid field";
		return -1;
	}
	*err = NULL;
	return 0;
}

void cal_map_stick(int right, int yl, int xl, int yr, int xr, int *x, int *y)
{
	if (right) {
		*x = xr;
		*y = yr;
	} else {
		*x = xl;
		*y = yl;
	}
}

int cal_parse_raw(const char *text, int *yl, int *xl, int *yr, int *xr,
		  const char **err)
{
	int seen_yl = 0, seen_xl = 0, seen_yr = 0, seen_xr = 0;
	int vyl = 0, vxl = 0, vyr = 0, vxr = 0;
	const char *p;

	if (!text || !yl || !xl || !yr || !xr) {
		*err = "malformed raw";
		return -1;
	}
	p = text;
	while (*p == ' ' || *p == '\t')
		p++;
	if (*p == 0 || *p == '\n') {
		*err = "incomplete raw";
		return -1;
	}
	while (*p && *p != '\n') {
		char key[8];
		int ki = 0;
		char *end;
		long v;
		int *slot;
		int *seen;

		while (*p == ' ' || *p == '\t')
			p++;
		if (*p == 0 || *p == '\n')
			break;
		while (*p && *p != '=' && *p != ' ' && *p != '\t' && *p != '\n') {
			if (ki < (int)sizeof(key) - 1)
				key[ki++] = *p;
			else {
				*err = "malformed raw";
				return -1;
			}
			p++;
		}
		key[ki] = 0;
		if (*p != '=' || ki == 0) {
			*err = "malformed raw";
			return -1;
		}
		p++;
		if (!isdigit((unsigned char)*p)) {
			*err = "malformed raw";
			return -1;
		}
		errno = 0;
		v = strtol(p, &end, 10);
		if (errno || end == p || v < 0 || v > 255) {
			*err = "malformed raw";
			return -1;
		}
		p = end;
		if (strcmp(key, "YL") == 0) {
			slot = &vyl;
			seen = &seen_yl;
		} else if (strcmp(key, "XL") == 0) {
			slot = &vxl;
			seen = &seen_xl;
		} else if (strcmp(key, "YR") == 0) {
			slot = &vyr;
			seen = &seen_yr;
		} else if (strcmp(key, "XR") == 0) {
			slot = &vxr;
			seen = &seen_xr;
		} else {
			*err = "malformed raw";
			return -1;
		}
		if (*seen) {
			*err = "malformed raw";
			return -1;
		}
		*slot = (int)v;
		*seen = 1;
	}
	if (*p == '\n')
		p++;
	while (*p == ' ' || *p == '\t' || *p == '\n')
		p++;
	if (*p) {
		*err = "malformed raw";
		return -1;
	}
	if (!seen_yl || !seen_xl || !seen_yr || !seen_xr) {
		*err = "incomplete raw";
		return -1;
	}
	*yl = vyl;
	*xl = vxl;
	*yr = vyr;
	*xr = vxr;
	*err = NULL;
	return 0;
}

void cal_cap_reset(cal_cap *cap)
{
	memset(cap, 0, sizeof(*cap));
	cap->x_min = 255;
	cap->y_min = 255;
	cap->zx_lo = 255;
	cap->zy_lo = 255;
}

void cal_cap_add_range(cal_cap *cap, int x, int y)
{
	if (x < 0 || x > 255 || y < 0 || y > 255)
		return;
	if (x < cap->x_min)
		cap->x_min = x;
	if (x > cap->x_max)
		cap->x_max = x;
	if (y < cap->y_min)
		cap->y_min = y;
	if (y > cap->y_max)
		cap->y_max = y;
	cap->range_n++;
}

void cal_cap_add_center(cal_cap *cap, int x, int y)
{
	if (x < 0 || x > 255 || y < 0 || y > 255)
		return;
	cap->zx_sum += x;
	cap->zy_sum += y;
	if (cap->zero_n == 0 || x < cap->zx_lo)
		cap->zx_lo = x;
	if (x > cap->zx_hi)
		cap->zx_hi = x;
	if (cap->zero_n == 0 || y < cap->zy_lo)
		cap->zy_lo = y;
	if (y > cap->zy_hi)
		cap->zy_hi = y;
	cap->zero_n++;
}

void cal_center_window_reset(cal_cap *cap)
{
	cap->zx_sum = cap->zy_sum = 0;
	cap->zero_n = 0;
	cap->zx_lo = cap->zy_lo = 255;
	cap->zx_hi = cap->zy_hi = 0;
}

int cal_range_ready(const cal_cap *cap)
{
	if (!cap || cap->range_n < 20)
		return 0;
	if ((cap->x_max - cap->x_min) < CAL_MIN_SPAN)
		return 0;
	if ((cap->y_max - cap->y_min) < CAL_MIN_SPAN)
		return 0;
	return 1;
}

int cal_center_window_stable(const cal_cap *cap)
{
	if (!cap || cap->zero_n < CAL_CENTER_SAMPLES)
		return 0;
	if ((cap->zx_hi - cap->zx_lo) > CAL_CENTER_SPREAD)
		return 0;
	if ((cap->zy_hi - cap->zy_lo) > CAL_CENTER_SPREAD)
		return 0;
	return 1;
}

int cal_cap_finish(const cal_cap *cap, cal_cfg *cfg, const char **err)
{
	int zx, zy;

	if (!cap || cap->range_n < 20) {
		*err = "Not enough movement";
		return -1;
	}
	if ((cap->x_max - cap->x_min) < CAL_MIN_SPAN ||
	    (cap->y_max - cap->y_min) < CAL_MIN_SPAN) {
		*err = "Insufficient movement";
		return -1;
	}
	if (cap->zero_n < CAL_CENTER_SAMPLES) {
		*err = "Not enough center samples";
		return -1;
	}
	if ((cap->zx_hi - cap->zx_lo) > CAL_CENTER_SPREAD ||
	    (cap->zy_hi - cap->zy_lo) > CAL_CENTER_SPREAD) {
		*err = "Unstable center";
		return -1;
	}
	zx = cap->zx_sum / cap->zero_n;
	zy = cap->zy_sum / cap->zero_n;
	cfg->x_min = cap->x_min;
	cfg->x_max = cap->x_max;
	cfg->x_zero = zx;
	cfg->y_min = cap->y_min;
	cfg->y_max = cap->y_max;
	cfg->y_zero = zy;
	if (cal_cfg_ok(cfg)) {
		*err = "Center is outside the captured range";
		return -1;
	}
	*err = NULL;
	return 0;
}

int cal_format(const cal_cfg *cfg, char *buf, size_t len)
{
	int n = snprintf(buf, len,
			 "x_min=%d\nx_max=%d\ny_min=%d\ny_max=%d\nx_zero=%d\ny_zero=%d\n",
			 cfg->x_min, cfg->x_max, cfg->y_min, cfg->y_max,
			 cfg->x_zero, cfg->y_zero);
	if (n < 0 || (size_t)n >= len)
		return -1;
	return 0;
}

int cal_apply_line(const cal_cfg *cfg, char *buf, size_t len)
{
	int n = snprintf(buf, len, "apply %d %d %d %d %d %d\n",
			 cfg->x_min, cfg->x_zero, cfg->x_max,
			 cfg->y_min, cfg->y_zero, cfg->y_max);
	if (n < 0 || (size_t)n >= len)
		return -1;
	return 0;
}

int cal_write_atomic(const char *path, const cal_cfg *cfg)
{
	char tmp[512];
	char body[256];
	int fd, n;
	size_t len;

	if (cal_format(cfg, body, sizeof(body)))
		return -1;
	n = snprintf(tmp, sizeof(tmp), "%s.tmp", path);
	if (n < 0 || (size_t)n >= sizeof(tmp))
		return -1;
	fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (fd < 0)
		return -1;
	len = strlen(body);
	if (write(fd, body, len) != (ssize_t)len || fsync(fd) != 0) {
		close(fd);
		unlink(tmp);
		return -1;
	}
	if (close(fd) != 0) {
		unlink(tmp);
		return -1;
	}
	if (rename(tmp, path) != 0) {
		unlink(tmp);
		return -1;
	}
	return 0;
}

int cal_commit(const cal_cfg *cfg, cal_apply_fn apply, void *ud,
	       const char *path, char *msg, size_t msg_len)
{
	char line[128];

	if (cal_cfg_ok(cfg) || cal_apply_line(cfg, line, sizeof(line))) {
		snprintf(msg, msg_len, "Invalid calibration");
		return 1;
	}
	if (!apply || apply(line, ud) != 0) {
		snprintf(msg, msg_len, "Apply failed");
		return 1;
	}
	if (cal_write_atomic(path, cfg) != 0) {
		snprintf(msg, msg_len, "Applied for this boot but save failed");
		return 2;
	}
	snprintf(msg, msg_len, "Calibration saved");
	return 0;
}
