#ifndef ZLYME_CAL_LOGIC_H
#define ZLYME_CAL_LOGIC_H

#include <stddef.h>

#define CAL_DEADBAND 2
#define CAL_MIN_SPAN 40
#define CAL_CENTER_SAMPLES 12
#define CAL_CENTER_SPREAD 3

typedef struct {
	int x_min, x_max, x_zero;
	int y_min, y_max, y_zero;
} cal_cfg;

typedef struct {
	int x_min, x_max, y_min, y_max;
	int range_n;
	int zx_sum, zy_sum, zero_n;
	int zx_lo, zx_hi, zy_lo, zy_hi;
} cal_cap;

int cal_center_ok(int min, int zero, int max);
int cal_cfg_ok(const cal_cfg *cfg);
/* 0 fills cfg. Nonzero sets *err: missing, duplicate, or invalid field. */
int cal_parse(const char *text, cal_cfg *cfg, const char **err);
/*
 * One snapshot: YL= XL= YR= XR=, any key order, values 0..255.
 * 0 fills the four outputs. Nonzero sets *err.
 */
int cal_parse_raw(const char *text, int *yl, int *xl, int *yr, int *xr,
		  const char **err);
/* left: x=XL y=YL. right: x=XR y=YR. */
void cal_map_stick(int right, int yl, int xl, int yr, int xr, int *x, int *y);

void cal_cap_reset(cal_cap *cap);
void cal_cap_add_range(cal_cap *cap, int x, int y);
void cal_cap_add_center(cal_cap *cap, int x, int y);
void cal_center_window_reset(cal_cap *cap);
int cal_center_window_stable(const cal_cap *cap);
int cal_range_ready(const cal_cap *cap);
/* 0 and fills cfg. Nonzero sets *err to a stable short reason. */
int cal_cap_finish(const cal_cap *cap, cal_cfg *cfg, const char **err);

int cal_format(const cal_cfg *cfg, char *buf, size_t len);
int cal_apply_line(const cal_cfg *cfg, char *buf, size_t len);

typedef int (*cal_apply_fn)(const char *line, void *ud);

/*
 * 0 both succeeded.
 * 1 apply failed; path untouched.
 * 2 apply succeeded, file replace failed.
 */
int cal_commit(const cal_cfg *cfg, cal_apply_fn apply, void *ud,
	       const char *path, char *msg, size_t msg_len);

int cal_write_atomic(const char *path, const cal_cfg *cfg);

#endif
