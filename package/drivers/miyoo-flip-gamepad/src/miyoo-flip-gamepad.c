// SPDX-License-Identifier: GPL-2.0-only
/*
 * Miyoo Flip gamepad.
 *
 * Copyright (c) 2026 Zlyme contributors
 *
 * One input device:
 *   UART1 serdev, 9600 8N1, frames FF YL XL YR XR FE
 *   seventeen GPIO buttons, interrupt plus software debounce
 *   PWM5 claimed and held off (FF_RUMBLE playback is later)
 *
 * Calibration lives in userspace files. This driver never opens them.
 * min/max and saved_zero are the persistent travel and center.
 * runtime_zero is what scaling uses. Its source is default,
 * persisted, boot, or apply. A boot center replaces a default or
 * persisted runtime center only when that center still fits the
 * active min/max. Apply is authoritative for this boot and stops
 * further boot-center acquisition on those axes. A restore that
 * would leave a preserved runtime center outside the new range
 * is rejected and changes nothing.
 * 0/128/255 is the uncalibrated protocol-byte fallback, not a
 * measured stick range.
 *
 * raw_axes is the stable read-only sample for manual calibration:
 * one locked snapshot, "YL=<n> XL=<n> YR=<n> XR=<n>".
 * The tracer attribute remains a diagnostic and is not a calibration ABI.
 */

#include <linux/device.h>
#include <linux/errno.h>
#include <linux/gpio/consumer.h>
#include <linux/input.h>
#include <linux/interrupt.h>
#include <linux/jiffies.h>
#include <linux/kernel.h>
#include <linux/math64.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/pm.h>
#include <linux/property.h>
#include <linux/pwm.h>
#include <linux/serdev.h>
#include <linux/spinlock.h>
#include <linux/string.h>
#include <linux/workqueue.h>

#define MF_NAME			"Miyoo Flip Gamepad"
#define MF_MAX_BUTTONS		17
#define MF_FRAME_LEN		6
#define MF_FRAME_START		0xff
#define MF_FRAME_END		0xfe

/*
 * Uncalibrated fallback across the whole unsigned UART byte.
 * Not measured physical travel. Original sticks reached 2..239;
 * replacement-stick extrema are still unknown. 0..255 avoids
 * clipping a stick whose real ends are outside an old guess.
 */
#define MF_DEFAULT_MIN		0
#define MF_DEFAULT_ZERO		128
#define MF_DEFAULT_MAX		255
#define MF_ABS_RANGE		32767
#define MF_RAW_DEADBAND		2
#define MF_DZ_MAX_PERCENT	30
/*
 * A written center only has to leave a positive divisor after the
 * deadband is removed. Narrow or asymmetric sticks are valid.
 * Travel-quality checks belong in the calibration UI.
 */
/*
 * Phase 3B boot-center tuning, not a stable ABI.
 * The first tracer accepted 15 frames (~225 ms) and locked XR on a
 * startup value. Wait for the pots to settle, then require two tight
 * windows to agree. Give up and keep the fallback zero if that does
 * not happen inside the budget. Do not recenter after that.
 */
#define MF_BOOT_SETTLE_MS	1500
#define MF_BOOT_WINDOW		31
#define MF_BOOT_SPREAD		3
#define MF_BOOT_MATCH		2
#define MF_BOOT_BUDGET_MS	6000
#define MF_DEBOUNCE_MS		10

enum mf_boot_state {
	MF_BOOT_WAIT = 0,
	MF_BOOT_SETTLE,
	MF_BOOT_COLLECT,
	MF_BOOT_CONFIRM,
	MF_BOOT_ACCEPTED,
	MF_BOOT_TIMEOUT,
	MF_BOOT_CANCELLED,
	MF_BOOT_RANGE_REJECTED,
};

enum mf_zero_source {
	MF_ZERO_DEFAULT = 0,
	MF_ZERO_PERSISTED,
	MF_ZERO_BOOT,
	MF_ZERO_APPLY,
};

enum mf_settle_phase {
	MF_SETTLE_WAIT = 0,
	MF_SETTLE_HW,
	MF_SETTLE_RUN,
	MF_SETTLE_DONE,
};

enum mf_axis_id {
	MF_XL = 0,
	MF_YL,
	MF_XR,
	MF_YR,
	MF_AXES
};

struct mf_pad;

struct mf_btn {
	struct mf_pad *pad;
	struct gpio_desc *gpio;
	struct delayed_work work;
	const char *label;
	unsigned int code;
	unsigned int debounce_ms;
	int irq;
};

struct mf_axis {
	int min;
	int saved_zero;
	int runtime_zero;
	int max;
	int abs_code;
	u8 latest;
	u8 seen_min;
	u8 seen_max;
	bool seen_valid;
	u8 samples[MF_BOOT_WINDOW];
	int n;
	int candidate;
	u8 boot_state;
	u8 zero_source;
	bool settled;
	bool accepted;
	int attempts;
};

struct mf_pad {
	struct device *dev;
	struct serdev_device *serdev;
	struct input_dev *input;
	struct pwm_device *pwm;
	struct mf_btn buttons[MF_MAX_BUTTONS];
	unsigned int nbuttons;
	struct mf_axis axis[MF_AXES];
	int last_abs[MF_AXES];
	u8 deadzone_left;
	u8 deadzone_right;
	u8 frame[MF_FRAME_LEN];
	u8 frame_len;
	unsigned long boot_first_jiffies;
	unsigned long boot_collect_jiffies;
	bool boot_started;
	u8 settle_phase;
	u32 valid_frames;
	u32 bad_frames;
	u32 rx_bytes;
	bool port_open;
	int open_errno;
	spinlock_t lock;
};

static void mf_axis_defaults(struct mf_axis *ax, int abs_code)
{
	ax->min = MF_DEFAULT_MIN;
	ax->saved_zero = MF_DEFAULT_ZERO;
	ax->runtime_zero = MF_DEFAULT_ZERO;
	ax->max = MF_DEFAULT_MAX;
	ax->abs_code = abs_code;
	ax->latest = MF_DEFAULT_ZERO;
	ax->candidate = -1;
	ax->boot_state = MF_BOOT_WAIT;
	ax->zero_source = MF_ZERO_DEFAULT;
}

static u8 mf_median(const u8 *src, int n)
{
	u8 tmp[MF_BOOT_WINDOW];
	int i, j;

	memcpy(tmp, src, n);
	for (i = 1; i < n; i++) {
		u8 v = tmp[i];

		j = i;
		while (j > 0 && tmp[j - 1] > v) {
			tmp[j] = tmp[j - 1];
			j--;
		}
		tmp[j] = v;
	}
	return tmp[n / 2];
}

/*
 * Continuous deadband. The first count outside the band is 0 at the
 * edge of the remaining span, not a full-scale step.
 * Provisional min/max stay the fallback. A non-positive span reports 0.
 */
static int mf_scale_side(int delta, int span)
{
	int out;

	if (delta <= MF_RAW_DEADBAND)
		return 0;
	span -= MF_RAW_DEADBAND;
	if (span <= 0)
		return 0;
	out = (delta - MF_RAW_DEADBAND) * MF_ABS_RANGE / span;
	if (out > MF_ABS_RANGE)
		out = MF_ABS_RANGE;
	if (out < 0)
		out = 0;
	return out;
}

static int mf_scale(int raw, const struct mf_axis *ax)
{
	if (raw >= ax->runtime_zero)
		return mf_scale_side(raw - ax->runtime_zero,
				     ax->max - ax->runtime_zero);
	return -mf_scale_side(ax->runtime_zero - raw,
			      ax->runtime_zero - ax->min);
}

/*
 * Scaled radial deadzone after independent axis normalization.
 * pct 0 returns the vector unchanged. Inside D both axes are 0.
 * Outside, ((r-D)*M)/(r*(M-D)) remaps the remainder to full travel.
 */
static void mf_radial(int pct, int *x, int *y)
{
	s64 xs, ys, num, den, d;
	u64 r;
	int ox, oy;

	if (pct <= 0)
		return;
	xs = *x;
	ys = *y;
	if (xs == 0 && ys == 0)
		return;
	r = int_sqrt64((u64)(xs * xs + ys * ys));
	if (r == 0)
		return;
	d = (s64)MF_ABS_RANGE * pct / 100;
	if ((s64)r <= d) {
		*x = 0;
		*y = 0;
		return;
	}
	num = ((s64)r - d) * MF_ABS_RANGE;
	den = (s64)r * (MF_ABS_RANGE - d);
	ox = (int)div_s64(xs * num, den);
	oy = (int)div_s64(ys * num, den);
	if (ox > MF_ABS_RANGE)
		ox = MF_ABS_RANGE;
	if (ox < -MF_ABS_RANGE)
		ox = -MF_ABS_RANGE;
	if (oy > MF_ABS_RANGE)
		oy = MF_ABS_RANGE;
	if (oy < -MF_ABS_RANGE)
		oy = -MF_ABS_RANGE;
	*x = ox;
	*y = oy;
}

/* Caller holds pad->lock. Both axes of the stick are current. */
static void mf_emit_stick(struct mf_pad *pad, int x_id, int y_id, int pct)
{
	int x, y;

	x = mf_scale(pad->axis[x_id].latest, &pad->axis[x_id]);
	y = mf_scale(pad->axis[y_id].latest, &pad->axis[y_id]);
	mf_radial(pct, &x, &y);
	pad->last_abs[x_id] = x;
	pad->last_abs[y_id] = y;
	input_report_abs(pad->input, pad->axis[x_id].abs_code, x);
	input_report_abs(pad->input, pad->axis[y_id].abs_code, y);
}

/* Caller holds pad->lock. raw[] is one complete UART frame. */
static void mf_report_axes(struct mf_pad *pad, const u8 raw[MF_AXES])
{
	int i;

	for (i = 0; i < MF_AXES; i++)
		pad->axis[i].latest = raw[i];
	mf_emit_stick(pad, MF_XL, MF_YL, pad->deadzone_left);
	mf_emit_stick(pad, MF_XR, MF_YR, pad->deadzone_right);
	input_sync(pad->input);
}

static void mf_note_seen(struct mf_axis *ax, u8 raw)
{
	ax->latest = raw;
	if (!ax->seen_valid) {
		ax->seen_min = raw;
		ax->seen_max = raw;
		ax->seen_valid = true;
		return;
	}
	if (raw < ax->seen_min)
		ax->seen_min = raw;
	if (raw > ax->seen_max)
		ax->seen_max = raw;
}

static bool mf_window_stable(const u8 *samples, int n, u8 *median_out)
{
	u8 lo = 255, hi = 0;
	int s;

	for (s = 0; s < n; s++) {
		if (samples[s] < lo)
			lo = samples[s];
		if (samples[s] > hi)
			hi = samples[s];
	}
	if ((unsigned int)(hi - lo) > MF_BOOT_SPREAD)
		return false;
	*median_out = mf_median(samples, n);
	return true;
}

static bool mf_boot_finished(u8 state)
{
	return state == MF_BOOT_ACCEPTED || state == MF_BOOT_TIMEOUT ||
	       state == MF_BOOT_CANCELLED || state == MF_BOOT_RANGE_REJECTED;
}

/*
 * Active span used for scaling. -EINVAL means the center is not
 * strictly inside the ends. -ERANGE means a side is not longer than
 * the deadband, so that side would not move. Callers reject the
 * whole stick write on either result.
 */
static int mf_center_in_range(int min, int zero, int max)
{
	if (min >= zero || zero >= max)
		return -EINVAL;
	if ((zero - min) <= MF_RAW_DEADBAND || (max - zero) <= MF_RAW_DEADBAND)
		return -ERANGE;
	return 0;
}

/*
 * Caller holds pad->lock. Never sleeps.
 * After the first frame, ignore candidates for MF_BOOT_SETTLE_MS.
 * Then two stable windows must agree within MF_BOOT_MATCH.
 * Stop at MF_BOOT_BUDGET_MS after settling and keep the fallback zero.
 */
static void mf_boot_note(struct mf_pad *pad, const u8 raw[MF_AXES])
{
	unsigned long now = jiffies;
	unsigned long settle = msecs_to_jiffies(MF_BOOT_SETTLE_MS);
	unsigned long budget = msecs_to_jiffies(MF_BOOT_BUDGET_MS);
	int i;

	for (i = 0; i < MF_AXES; i++)
		mf_note_seen(&pad->axis[i], raw[i]);

	if (!pad->boot_started) {
		pad->boot_started = true;
		pad->boot_first_jiffies = now;
		pad->settle_phase = MF_SETTLE_HW;
		for (i = 0; i < MF_AXES; i++) {
			if (pad->axis[i].zero_source == MF_ZERO_APPLY)
				continue;
			pad->axis[i].boot_state = MF_BOOT_SETTLE;
		}
	}

	if (pad->settle_phase == MF_SETTLE_HW) {
		if (time_before(now, pad->boot_first_jiffies + settle))
			return;
		pad->boot_collect_jiffies = now;
		pad->settle_phase = MF_SETTLE_RUN;
		for (i = 0; i < MF_AXES; i++) {
			if (pad->axis[i].boot_state == MF_BOOT_SETTLE) {
				pad->axis[i].boot_state = MF_BOOT_COLLECT;
				pad->axis[i].n = 0;
			}
		}
	}

	if (pad->settle_phase != MF_SETTLE_RUN)
		return;

	for (i = 0; i < MF_AXES; i++) {
		struct mf_axis *ax = &pad->axis[i];
		u8 med;

		if (mf_boot_finished(ax->boot_state))
			continue;

		if (time_after(now, pad->boot_collect_jiffies + budget)) {
			ax->boot_state = MF_BOOT_TIMEOUT;
			ax->settled = true;
			ax->accepted = false;
			continue;
		}

		ax->samples[ax->n++] = raw[i];
		if (ax->n < MF_BOOT_WINDOW)
			continue;

		ax->n = 0;
		ax->attempts++;
		if (!mf_window_stable(ax->samples, MF_BOOT_WINDOW, &med)) {
			ax->candidate = -1;
			ax->boot_state = MF_BOOT_COLLECT;
			continue;
		}

		if (ax->boot_state != MF_BOOT_CONFIRM) {
			ax->candidate = med;
			ax->boot_state = MF_BOOT_CONFIRM;
			continue;
		}

		if (abs(med - ax->candidate) <= MF_BOOT_MATCH) {
			if (mf_center_in_range(ax->min, med, ax->max)) {
				ax->settled = true;
				ax->accepted = false;
				ax->boot_state = MF_BOOT_RANGE_REJECTED;
				continue;
			}
			ax->runtime_zero = med;
			ax->zero_source = MF_ZERO_BOOT;
			ax->accepted = true;
			ax->settled = true;
			ax->boot_state = MF_BOOT_ACCEPTED;
		} else {
			ax->candidate = -1;
			ax->boot_state = MF_BOOT_COLLECT;
		}
	}

	for (i = 0; i < MF_AXES; i++) {
		if (!mf_boot_finished(pad->axis[i].boot_state))
			return;
	}
	pad->settle_phase = MF_SETTLE_DONE;
}

/* Caller holds pad->lock. */
static void mf_feed(struct mf_pad *pad, u8 byte)
{
	u8 raw[MF_AXES];
	int i, start;

	pad->rx_bytes++;

	if (pad->frame_len == 0) {
		if (byte == MF_FRAME_START)
			pad->frame[pad->frame_len++] = byte;
		return;
	}

	pad->frame[pad->frame_len++] = byte;
	if (pad->frame_len < MF_FRAME_LEN)
		return;

	if (pad->frame[MF_FRAME_LEN - 1] == MF_FRAME_END) {
		pad->valid_frames++;
		raw[MF_XL] = pad->frame[2];
		raw[MF_YL] = pad->frame[1];
		raw[MF_XR] = pad->frame[4];
		raw[MF_YR] = pad->frame[3];
		mf_boot_note(pad, raw);
		mf_report_axes(pad, raw);
		pad->frame_len = 0;
		return;
	}

	pad->bad_frames++;
	start = -1;
	for (i = 1; i < MF_FRAME_LEN; i++) {
		if (pad->frame[i] == MF_FRAME_START) {
			start = i;
			break;
		}
	}
	if (start < 0) {
		pad->frame_len = 0;
		return;
	}
	memmove(pad->frame, pad->frame + start, MF_FRAME_LEN - start);
	pad->frame_len = MF_FRAME_LEN - start;
}

static size_t mf_receive(struct serdev_device *serdev, const u8 *buf, size_t count)
{
	struct mf_pad *pad = serdev_device_get_drvdata(serdev);
	unsigned long flags;
	size_t i;

	spin_lock_irqsave(&pad->lock, flags);
	if (!pad->port_open) {
		spin_unlock_irqrestore(&pad->lock, flags);
		return count;
	}
	for (i = 0; i < count; i++)
		mf_feed(pad, buf[i]);
	spin_unlock_irqrestore(&pad->lock, flags);
	return count;
}

static const struct serdev_device_ops mf_serdev_ops = {
	.receive_buf = mf_receive,
};

static int mf_port_open(struct mf_pad *pad)
{
	unsigned long flags;
	unsigned int baud;
	int ret;

	ret = serdev_device_open(pad->serdev);
	if (ret) {
		pad->open_errno = ret;
		return ret;
	}

	baud = serdev_device_set_baudrate(pad->serdev, 9600);
	serdev_device_set_flow_control(pad->serdev, false);
	ret = serdev_device_set_parity(pad->serdev, SERDEV_PARITY_NONE);
	if (ret)
		dev_warn(pad->dev, "parity setup failed: %d\n", ret);
	if (baud != 9600)
		dev_warn(pad->dev, "line rate %u, wanted 9600\n", baud);

	spin_lock_irqsave(&pad->lock, flags);
	pad->frame_len = 0;
	pad->port_open = true;
	pad->open_errno = 0;
	spin_unlock_irqrestore(&pad->lock, flags);
	return 0;
}

static void mf_port_close(struct mf_pad *pad)
{
	unsigned long flags;
	bool was_open;

	spin_lock_irqsave(&pad->lock, flags);
	was_open = pad->port_open;
	pad->port_open = false;
	pad->frame_len = 0;
	spin_unlock_irqrestore(&pad->lock, flags);

	if (was_open)
		serdev_device_close(pad->serdev);
}

static void mf_btn_work(struct work_struct *work)
{
	struct mf_btn *btn = container_of(work, struct mf_btn, work.work);
	struct mf_pad *pad = btn->pad;
	unsigned long flags;
	int pressed;

	pressed = gpiod_get_value_cansleep(btn->gpio);
	if (pressed < 0)
		return;

	spin_lock_irqsave(&pad->lock, flags);
	input_report_key(pad->input, btn->code, pressed);
	input_sync(pad->input);
	spin_unlock_irqrestore(&pad->lock, flags);
}

static irqreturn_t mf_btn_irq(int irq, void *data)
{
	struct mf_btn *btn = data;
	unsigned int ms = btn->debounce_ms ? btn->debounce_ms : 1;

	mod_delayed_work(system_wq, &btn->work, msecs_to_jiffies(ms));
	return IRQ_HANDLED;
}

static int mf_buttons_setup(struct mf_pad *pad)
{
	int ret = 0;

	device_for_each_child_node_scoped(pad->dev, child) {
		struct mf_btn *btn;
		u32 code, debounce = MF_DEBOUNCE_MS;
		const char *label = "button";

		if (!fwnode_property_present(child, "gpios"))
			continue;
		if (pad->nbuttons >= MF_MAX_BUTTONS) {
			dev_warn(pad->dev, "extra GPIO button ignored\n");
			continue;
		}

		if (fwnode_property_read_u32(child, "linux,code", &code)) {
			dev_err(pad->dev, "button missing linux,code\n");
			ret = -EINVAL;
			continue;
		}
		fwnode_property_read_string(child, "label", &label);
		fwnode_property_read_u32(child, "debounce-interval", &debounce);

		btn = &pad->buttons[pad->nbuttons];
		btn->pad = pad;
		btn->code = code;
		btn->label = label;
		btn->debounce_ms = debounce;
		btn->irq = -1;
		INIT_DELAYED_WORK(&btn->work, mf_btn_work);

		btn->gpio = devm_fwnode_gpiod_get(pad->dev, child, NULL,
						  GPIOD_IN, label);
		if (IS_ERR(btn->gpio)) {
			dev_err(pad->dev, "%s gpio: %ld\n", label,
				PTR_ERR(btn->gpio));
			ret = PTR_ERR(btn->gpio);
			continue;
		}

		input_set_capability(pad->input, EV_KEY, code);
		pad->nbuttons++;
	}

	return ret;
}

static int mf_buttons_irqs(struct mf_pad *pad)
{
	unsigned int i;
	int ret;

	for (i = 0; i < pad->nbuttons; i++) {
		struct mf_btn *btn = &pad->buttons[i];

		btn->irq = gpiod_to_irq(btn->gpio);
		if (btn->irq < 0) {
			dev_err(pad->dev, "%s gpiod_to_irq: %d\n",
				btn->label, btn->irq);
			return btn->irq;
		}

		ret = devm_request_irq(pad->dev, btn->irq, mf_btn_irq,
				       IRQF_TRIGGER_RISING | IRQF_TRIGGER_FALLING,
				       btn->label, btn);
		if (ret) {
			dev_err(pad->dev, "%s request_irq: %d\n",
				btn->label, ret);
			btn->irq = -1;
			return ret;
		}
		dev_info(pad->dev, "button %s code %u irq %d debounce %u ms\n",
			 btn->label, btn->code, btn->irq, btn->debounce_ms);
	}
	return 0;
}

static void mf_pwm_hold_off(struct mf_pad *pad)
{
	struct pwm_state state;
	int ret;

	pad->pwm = devm_pwm_get(pad->dev, "enable");
	if (IS_ERR(pad->pwm)) {
		dev_warn(pad->dev, "pwm5 not claimed: %ld\n",
			 PTR_ERR(pad->pwm));
		pad->pwm = NULL;
		return;
	}

	pwm_init_state(pad->pwm, &state);
	state.enabled = false;
	state.duty_cycle = 0;
	ret = pwm_apply_might_sleep(pad->pwm, &state);
	if (ret)
		dev_warn(pad->dev, "pwm5 off failed: %d\n", ret);
}

static const char *mf_boot_word(u8 state)
{
	switch (state) {
	case MF_BOOT_WAIT:
		return "wait";
	case MF_BOOT_SETTLE:
		return "settling";
	case MF_BOOT_COLLECT:
		return "collecting";
	case MF_BOOT_CONFIRM:
		return "confirm";
	case MF_BOOT_ACCEPTED:
		return "accepted";
	case MF_BOOT_TIMEOUT:
		return "timeout";
	case MF_BOOT_CANCELLED:
		return "cancelled";
	case MF_BOOT_RANGE_REJECTED:
		return "range-rejected";
	default:
		return "unknown";
	}
}

static const char *mf_zero_word(u8 source)
{
	switch (source) {
	case MF_ZERO_DEFAULT:
		return "default";
	case MF_ZERO_PERSISTED:
		return "persisted";
	case MF_ZERO_BOOT:
		return "boot";
	case MF_ZERO_APPLY:
		return "apply";
	default:
		return "unknown";
	}
}

static const char *mf_settle_word(u8 phase)
{
	switch (phase) {
	case MF_SETTLE_WAIT:
		return "wait";
	case MF_SETTLE_HW:
		return "settling";
	case MF_SETTLE_RUN:
		return "collecting";
	case MF_SETTLE_DONE:
		return "done";
	default:
		return "unknown";
	}
}

static ssize_t tracer_show(struct device *dev, struct device_attribute *attr,
			   char *buf)
{
	struct mf_pad *pad = dev_get_drvdata(dev);
	struct mf_axis ax[MF_AXES];
	int last[MF_AXES];
	unsigned int nbuttons;
	u32 valid, bad, bytes;
	bool open;
	int err;
	u8 settle;
	unsigned long flags;

	spin_lock_irqsave(&pad->lock, flags);
	memcpy(ax, pad->axis, sizeof(ax));
	memcpy(last, pad->last_abs, sizeof(last));
	nbuttons = pad->nbuttons;
	valid = pad->valid_frames;
	bad = pad->bad_frames;
	bytes = pad->rx_bytes;
	open = pad->port_open;
	err = pad->open_errno;
	settle = pad->settle_phase;
	spin_unlock_irqrestore(&pad->lock, flags);

	return sysfs_emit(buf,
		"raw YL=%u XL=%u YR=%u XR=%u\n"
		"seen_min YL=%u XL=%u YR=%u XR=%u\n"
		"seen_max YL=%u XL=%u YR=%u XR=%u\n"
		"runtime_zero YL=%d XL=%d YR=%d XR=%d\n"
		"source YL=%s XL=%s YR=%s XR=%s\n"
		"saved_zero YL=%d XL=%d YR=%d XR=%d\n"
		"min YL=%d XL=%d YR=%d XR=%d\n"
		"max YL=%d XL=%d YR=%d XR=%d\n"
		"abs X=%d Y=%d RX=%d RY=%d\n"
		"valid=%u bad=%u bytes=%u\n"
		"boot YL=%s XL=%s YR=%s XR=%s\n"
		"cand YL=%d XL=%d YR=%d XR=%d\n"
		"windows YL=%d XL=%d YR=%d XR=%d\n"
		"settle=%s\n"
		"buttons=%u port=%s open_errno=%d\n",
		ax[MF_YL].latest, ax[MF_XL].latest,
		ax[MF_YR].latest, ax[MF_XR].latest,
		ax[MF_YL].seen_min, ax[MF_XL].seen_min,
		ax[MF_YR].seen_min, ax[MF_XR].seen_min,
		ax[MF_YL].seen_max, ax[MF_XL].seen_max,
		ax[MF_YR].seen_max, ax[MF_XR].seen_max,
		ax[MF_YL].runtime_zero, ax[MF_XL].runtime_zero,
		ax[MF_YR].runtime_zero, ax[MF_XR].runtime_zero,
		mf_zero_word(ax[MF_YL].zero_source),
		mf_zero_word(ax[MF_XL].zero_source),
		mf_zero_word(ax[MF_YR].zero_source),
		mf_zero_word(ax[MF_XR].zero_source),
		ax[MF_YL].saved_zero, ax[MF_XL].saved_zero,
		ax[MF_YR].saved_zero, ax[MF_XR].saved_zero,
		ax[MF_YL].min, ax[MF_XL].min, ax[MF_YR].min, ax[MF_XR].min,
		ax[MF_YL].max, ax[MF_XL].max, ax[MF_YR].max, ax[MF_XR].max,
		last[MF_XL], last[MF_YL], last[MF_XR], last[MF_YR],
		valid, bad, bytes,
		mf_boot_word(ax[MF_YL].boot_state),
		mf_boot_word(ax[MF_XL].boot_state),
		mf_boot_word(ax[MF_YR].boot_state),
		mf_boot_word(ax[MF_XR].boot_state),
		ax[MF_YL].candidate, ax[MF_XL].candidate,
		ax[MF_YR].candidate, ax[MF_XR].candidate,
		ax[MF_YL].attempts, ax[MF_XL].attempts,
		ax[MF_YR].attempts, ax[MF_XR].attempts,
		mf_settle_word(settle),
		nbuttons, open ? "open" : "closed", err);
}
static DEVICE_ATTR_RO(tracer);

static ssize_t raw_axes_show(struct device *dev,
			     struct device_attribute *attr, char *buf)
{
	struct mf_pad *pad = dev_get_drvdata(dev);
	u8 yl, xl, yr, xr;
	unsigned long flags;

	spin_lock_irqsave(&pad->lock, flags);
	yl = pad->axis[MF_YL].latest;
	xl = pad->axis[MF_XL].latest;
	yr = pad->axis[MF_YR].latest;
	xr = pad->axis[MF_XR].latest;
	spin_unlock_irqrestore(&pad->lock, flags);

	return sysfs_emit(buf, "YL=%u XL=%u YR=%u XR=%u\n", yl, xl, yr, xr);
}
static DEVICE_ATTR_RO(raw_axes);

static int mf_token_u8(const char **pp, int *out)
{
	const char *s = *pp;
	unsigned int v = 0;
	int digits = 0;

	while (*s == ' ' || *s == '\t')
		s++;
	if (*s < '0' || *s > '9')
		return -EINVAL;
	while (*s >= '0' && *s <= '9') {
		digits++;
		if (digits > 3)
			return -EINVAL;
		v = v * 10u + (unsigned int)(*s - '0');
		if (v > 255)
			return -EINVAL;
		s++;
	}
	*out = (int)v;
	*pp = s;
	return 0;
}

/* Caller holds pad->lock. 0, or the errno for a rejected stick. */
static int mf_preflight_axis(const struct mf_axis *ax, bool apply,
			     int min, int zero, int max)
{
	/*
	 * apply, and a restore that adopts the supplied zero, were
	 * already checked against that zero. A preserved boot or
	 * apply center must also fit the proposed ends.
	 */
	if (!apply && (ax->zero_source == MF_ZERO_BOOT ||
		       ax->zero_source == MF_ZERO_APPLY))
		return mf_center_in_range(min, ax->runtime_zero, max);
	return 0;
}

/*
 * Both axes are parsed and checked before either one is installed.
 * A rejected write leaves the stick unchanged.
 */
static int mf_parse_cal(const char *buf, bool *apply,
			int *xmin, int *xzero, int *xmax,
			int *ymin, int *yzero, int *ymax)
{
	const char *s = buf;
	char cmd[16];
	int n = 0;

	while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r')
		s++;
	while (*s && *s != ' ' && *s != '\t' && *s != '\n' && *s != '\r') {
		if (n >= 15)
			return -EINVAL;
		cmd[n++] = *s++;
	}
	cmd[n] = '\0';
	if (!strcmp(cmd, "restore"))
		*apply = false;
	else if (!strcmp(cmd, "apply"))
		*apply = true;
	else
		return -EINVAL;

	if (mf_token_u8(&s, xmin) || mf_token_u8(&s, xzero) ||
	    mf_token_u8(&s, xmax) || mf_token_u8(&s, ymin) ||
	    mf_token_u8(&s, yzero) || mf_token_u8(&s, ymax))
		return -EINVAL;
	while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r')
		s++;
	if (*s != '\0')
		return -EINVAL;
	if (mf_center_in_range(*xmin, *xzero, *xmax) ||
	    mf_center_in_range(*ymin, *yzero, *ymax))
		return -EINVAL;
	return 0;
}

/* Caller holds pad->lock. */
static void mf_install_axis(struct mf_axis *ax, int min, int zero, int max,
			    bool apply)
{
	ax->min = min;
	ax->saved_zero = zero;
	ax->max = max;
	if (apply) {
		ax->runtime_zero = zero;
		ax->zero_source = MF_ZERO_APPLY;
		if (!mf_boot_finished(ax->boot_state))
			ax->boot_state = MF_BOOT_CANCELLED;
		return;
	}
	if (ax->zero_source == MF_ZERO_DEFAULT ||
	    ax->zero_source == MF_ZERO_PERSISTED) {
		ax->runtime_zero = zero;
		ax->zero_source = MF_ZERO_PERSISTED;
	}
}

/* Caller holds pad->lock. Republish the latest raw pair for this stick. */
static void mf_publish_stick(struct mf_pad *pad, int x_id, int y_id)
{
	int pct = (x_id == MF_XL) ? pad->deadzone_left : pad->deadzone_right;

	mf_emit_stick(pad, x_id, y_id, pct);
	input_sync(pad->input);
}

static ssize_t mf_cal_show(struct mf_pad *pad, int x_id, int y_id, char *buf)
{
	struct mf_axis x, y;
	unsigned long flags;

	spin_lock_irqsave(&pad->lock, flags);
	x = pad->axis[x_id];
	y = pad->axis[y_id];
	spin_unlock_irqrestore(&pad->lock, flags);

	return sysfs_emit(buf,
		"x_min=%d\n"
		"x_saved_zero=%d\n"
		"x_runtime_zero=%d\n"
		"x_max=%d\n"
		"x_source=%s\n"
		"y_min=%d\n"
		"y_saved_zero=%d\n"
		"y_runtime_zero=%d\n"
		"y_max=%d\n"
		"y_source=%s\n",
		x.min, x.saved_zero, x.runtime_zero, x.max, mf_zero_word(x.zero_source),
		y.min, y.saved_zero, y.runtime_zero, y.max, mf_zero_word(y.zero_source));
}

static ssize_t mf_cal_store(struct mf_pad *pad, int x_id, int y_id,
			    const char *buf, size_t count)
{
	bool apply;
	int xmin, xzero, xmax, ymin, yzero, ymax;
	unsigned long flags;

	if (mf_parse_cal(buf, &apply, &xmin, &xzero, &xmax,
			 &ymin, &yzero, &ymax))
		return -EINVAL;

	spin_lock_irqsave(&pad->lock, flags);
	if (mf_preflight_axis(&pad->axis[x_id], apply, xmin, xzero, xmax) ||
	    mf_preflight_axis(&pad->axis[y_id], apply, ymin, yzero, ymax)) {
		spin_unlock_irqrestore(&pad->lock, flags);
		return -ERANGE;
	}
	mf_install_axis(&pad->axis[x_id], xmin, xzero, xmax, apply);
	mf_install_axis(&pad->axis[y_id], ymin, yzero, ymax, apply);
	if (pad->boot_started) {
		int i;

		for (i = 0; i < MF_AXES; i++) {
			if (!mf_boot_finished(pad->axis[i].boot_state))
				break;
		}
		if (i == MF_AXES)
			pad->settle_phase = MF_SETTLE_DONE;
	}
	mf_publish_stick(pad, x_id, y_id);
	spin_unlock_irqrestore(&pad->lock, flags);
	return count;
}

static ssize_t calibration_left_show(struct device *dev,
				     struct device_attribute *attr, char *buf)
{
	struct mf_pad *pad = dev_get_drvdata(dev);

	return mf_cal_show(pad, MF_XL, MF_YL, buf);
}

static ssize_t calibration_left_store(struct device *dev,
				      struct device_attribute *attr,
				      const char *buf, size_t count)
{
	struct mf_pad *pad = dev_get_drvdata(dev);

	return mf_cal_store(pad, MF_XL, MF_YL, buf, count);
}
static DEVICE_ATTR_RW(calibration_left);

static ssize_t calibration_right_show(struct device *dev,
				      struct device_attribute *attr, char *buf)
{
	struct mf_pad *pad = dev_get_drvdata(dev);

	return mf_cal_show(pad, MF_XR, MF_YR, buf);
}

static ssize_t calibration_right_store(struct device *dev,
				       struct device_attribute *attr,
				       const char *buf, size_t count)
{
	struct mf_pad *pad = dev_get_drvdata(dev);

	return mf_cal_store(pad, MF_XR, MF_YR, buf, count);
}
static DEVICE_ATTR_RW(calibration_right);

static int mf_dz_pct(struct mf_pad *pad, bool right)
{
	return right ? pad->deadzone_right : pad->deadzone_left;
}

static ssize_t mf_dz_show(struct mf_pad *pad, bool right, char *buf)
{
	unsigned long flags;
	int pct;

	spin_lock_irqsave(&pad->lock, flags);
	pct = mf_dz_pct(pad, right);
	spin_unlock_irqrestore(&pad->lock, flags);
	return sysfs_emit(buf, "%d\n", pct);
}

static ssize_t mf_dz_store(struct mf_pad *pad, bool right, const char *buf,
			   size_t count)
{
	unsigned int pct;
	unsigned long flags;
	int x_id, y_id;

	while (*buf == ' ' || *buf == '\t')
		buf++;
	if (kstrtouint(buf, 10, &pct) || pct > MF_DZ_MAX_PERCENT)
		return -EINVAL;
	x_id = right ? MF_XR : MF_XL;
	y_id = right ? MF_YR : MF_YL;
	spin_lock_irqsave(&pad->lock, flags);
	if (right)
		pad->deadzone_right = pct;
	else
		pad->deadzone_left = pct;
	mf_publish_stick(pad, x_id, y_id);
	spin_unlock_irqrestore(&pad->lock, flags);
	return count;
}

static ssize_t deadzone_left_show(struct device *dev,
				  struct device_attribute *attr, char *buf)
{
	return mf_dz_show(dev_get_drvdata(dev), false, buf);
}

static ssize_t deadzone_left_store(struct device *dev,
				   struct device_attribute *attr,
				   const char *buf, size_t count)
{
	return mf_dz_store(dev_get_drvdata(dev), false, buf, count);
}
static DEVICE_ATTR_RW(deadzone_left);

static ssize_t deadzone_right_show(struct device *dev,
				   struct device_attribute *attr, char *buf)
{
	return mf_dz_show(dev_get_drvdata(dev), true, buf);
}

static ssize_t deadzone_right_store(struct device *dev,
				    struct device_attribute *attr,
				    const char *buf, size_t count)
{
	return mf_dz_store(dev_get_drvdata(dev), true, buf, count);
}
static DEVICE_ATTR_RW(deadzone_right);

static struct attribute *mf_attrs[] = {
	&dev_attr_tracer.attr,
	&dev_attr_raw_axes.attr,
	&dev_attr_deadzone_left.attr,
	&dev_attr_deadzone_right.attr,
	&dev_attr_calibration_left.attr,
	&dev_attr_calibration_right.attr,
	NULL
};

static const struct attribute_group mf_attr_group = {
	.attrs = mf_attrs,
};

static void mf_buttons_stop(struct mf_pad *pad)
{
	unsigned int i;

	for (i = 0; i < pad->nbuttons; i++) {
		if (pad->buttons[i].irq >= 0)
			disable_irq(pad->buttons[i].irq);
	}
	for (i = 0; i < pad->nbuttons; i++)
		cancel_delayed_work_sync(&pad->buttons[i].work);
}

static int mf_probe(struct serdev_device *serdev)
{
	struct device *dev = &serdev->dev;
	struct mf_pad *pad;
	int i, ret;

	pad = devm_kzalloc(dev, sizeof(*pad), GFP_KERNEL);
	if (!pad)
		return -ENOMEM;

	pad->dev = dev;
	pad->serdev = serdev;
	pad->open_errno = -ENODEV;
	spin_lock_init(&pad->lock);
	serdev_device_set_drvdata(serdev, pad);
	serdev_device_set_client_ops(serdev, &mf_serdev_ops);

	mf_axis_defaults(&pad->axis[MF_XL], ABS_X);
	mf_axis_defaults(&pad->axis[MF_YL], ABS_Y);
	mf_axis_defaults(&pad->axis[MF_XR], ABS_RX);
	mf_axis_defaults(&pad->axis[MF_YR], ABS_RY);

	pad->input = devm_input_allocate_device(dev);
	if (!pad->input)
		return -ENOMEM;

	pad->input->name = MF_NAME;
	pad->input->phys = "miyoo-flip-gamepad/input0";
	pad->input->id.bustype = BUS_HOST;
	pad->input->id.vendor = 0;
	pad->input->id.product = 0;
	pad->input->id.version = 0;
	input_set_drvdata(pad->input, pad);

	for (i = 0; i < MF_AXES; i++)
		input_set_abs_params(pad->input, pad->axis[i].abs_code,
				     -MF_ABS_RANGE, MF_ABS_RANGE, 0, 0);

	ret = mf_buttons_setup(pad);
	if (pad->nbuttons == 0) {
		dev_err(dev, "no buttons available: %d\n", ret);
		return ret ? ret : -ENODEV;
	}
	if (ret)
		dev_warn(dev, "some buttons failed to request\n");

	ret = input_register_device(pad->input);
	if (ret)
		return ret;

	for (i = 0; i < pad->nbuttons; i++) {
		int pressed = gpiod_get_value_cansleep(pad->buttons[i].gpio);

		if (pressed >= 0)
			input_report_key(pad->input, pad->buttons[i].code, pressed);
	}
	input_sync(pad->input);

	ret = mf_buttons_irqs(pad);
	if (ret) {
		mf_buttons_stop(pad);
		return ret;
	}

	mf_pwm_hold_off(pad);

	ret = device_add_group(dev, &mf_attr_group);
	if (ret) {
		mf_buttons_stop(pad);
		return ret;
	}

	ret = mf_port_open(pad);
	if (ret)
		dev_err(dev, "serdev open failed: %d; buttons stay available\n",
			ret);
	else
		dev_info(dev, "UART1 open 9600 8N1, no hardware flow control\n");

	dev_info(dev, "%s ready, %u buttons\n", MF_NAME, pad->nbuttons);
	return 0;
}

static void mf_remove(struct serdev_device *serdev)
{
	struct mf_pad *pad = serdev_device_get_drvdata(serdev);

	device_remove_group(&serdev->dev, &mf_attr_group);
	mf_port_close(pad);
	mf_buttons_stop(pad);
}

static int mf_suspend(struct device *dev)
{
	struct mf_pad *pad = serdev_device_get_drvdata(to_serdev_device(dev));

	mf_port_close(pad);
	return 0;
}

static int mf_resume(struct device *dev)
{
	struct mf_pad *pad = serdev_device_get_drvdata(to_serdev_device(dev));
	int ret;

	ret = mf_port_open(pad);
	if (ret)
		dev_err(dev, "resume serdev open failed: %d; buttons stay available\n",
			ret);
	return 0;
}

static const struct dev_pm_ops mf_pm_ops = {
	.suspend = mf_suspend,
	.resume = mf_resume,
};

static const struct of_device_id mf_of_match[] = {
	{ .compatible = "miyoo,flip-gamepad" },
	{ }
};
MODULE_DEVICE_TABLE(of, mf_of_match);

static struct serdev_device_driver mf_driver = {
	.driver = {
		.name = "miyoo-flip-gamepad",
		.of_match_table = mf_of_match,
		.pm = &mf_pm_ops,
	},
	.probe = mf_probe,
	.remove = mf_remove,
};
module_serdev_device_driver(mf_driver);

MODULE_AUTHOR("Zlyme contributors");
MODULE_DESCRIPTION("Miyoo Flip gamepad");
MODULE_LICENSE("GPL");
