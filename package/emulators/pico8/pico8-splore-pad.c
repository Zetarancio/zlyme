/* Splore is a mouse/keyboard UI. The Flip dpad is buttons, not a hat,
 * so PICO-8's joystick path does nothing in the BBS browser. Grab the
 * pad and emit keys + relative mouse (same idea as Knulli evmapy). */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <unistd.h>

#include "virtpad.h"

static volatile sig_atomic_t running = 1;
static pid_t child_pid;

static void on_sig(int sig)
{
	running = 0;
	if (child_pid > 0)
		kill(child_pid, sig == SIGINT ? SIGINT : SIGTERM);
}

static int find_virtpad(char *out, size_t outlen)
{
	DIR *dir;
	struct dirent *ent;

	dir = opendir("/dev/input");
	if (!dir)
		return -1;
	while ((ent = readdir(dir))) {
		char path[320];
		int fd;

		if (strncmp(ent->d_name, "event", 5) != 0)
			continue;
		if (strlen(ent->d_name) > 16)
			continue;
		snprintf(path, sizeof path, "/dev/input/%s", ent->d_name);
		fd = open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK);
		if (fd < 0)
			continue;
		if (!zlyme_is_virtpad(fd, ent->d_name)) {
			close(fd);
			continue;
		}
		close(fd);
		snprintf(out, outlen, "%s", path);
		closedir(dir);
		return 0;
	}
	closedir(dir);
	return -1;
}

static void emit_key(int fd, int code, int value);

static void set_hat(int dst, int *slot, int value, int neg_key, int pos_key)
{
	int v = 0;

	if (value < 0)
		v = -1;
	else if (value > 0)
		v = 1;
	if (v == *slot)
		return;
	if (*slot < 0)
		emit_key(dst, neg_key, 0);
	if (*slot > 0)
		emit_key(dst, pos_key, 0);
	if (v < 0)
		emit_key(dst, neg_key, 1);
	if (v > 0)
		emit_key(dst, pos_key, 1);
	*slot = v;
}

static int setup_uinput(void)
{
	int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	struct uinput_setup setup;
	const int keys[] = {
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
		KEY_Z, KEY_X, KEY_C, KEY_V,
		KEY_ENTER, KEY_ESC, BTN_LEFT, BTN_RIGHT,
	};
	unsigned i;

	if (fd < 0)
		return -1;
	ioctl(fd, UI_SET_EVBIT, EV_KEY);
	ioctl(fd, UI_SET_EVBIT, EV_REL);
	ioctl(fd, UI_SET_EVBIT, EV_SYN);
	for (i = 0; i < sizeof(keys) / sizeof(keys[0]); i++)
		ioctl(fd, UI_SET_KEYBIT, keys[i]);
	ioctl(fd, UI_SET_RELBIT, REL_X);
	ioctl(fd, UI_SET_RELBIT, REL_Y);
	ioctl(fd, UI_SET_RELBIT, REL_WHEEL);

	memset(&setup, 0, sizeof(setup));
	setup.id.bustype = BUS_VIRTUAL;
	setup.id.vendor = 0x0001;
	setup.id.product = 0x0001;
	snprintf(setup.name, sizeof(setup.name), "pico8-splore-pad");
	if (ioctl(fd, UI_DEV_SETUP, &setup) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
		close(fd);
		return -1;
	}
	usleep(80000);
	return fd;
}

static void emit(int fd, int type, int code, int value)
{
	struct input_event ev;

	memset(&ev, 0, sizeof(ev));
	ev.type = type;
	ev.code = code;
	ev.value = value;
	if (write(fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev))
		running = 0;
}

static void emit_key(int fd, int code, int value)
{
	emit(fd, EV_KEY, code, value ? 1 : 0);
	emit(fd, EV_SYN, SYN_REPORT, 0);
}

static int map_key(int code)
{
	switch (code) {
	case BTN_DPAD_UP:
		return KEY_UP;
	case BTN_DPAD_DOWN:
		return KEY_DOWN;
	case BTN_DPAD_LEFT:
		return KEY_LEFT;
	case BTN_DPAD_RIGHT:
		return KEY_RIGHT;
	case BTN_SOUTH:
		return KEY_Z;
	case BTN_EAST:
		return KEY_X;
	case BTN_NORTH:
		return KEY_Z;
	case BTN_WEST:
		return KEY_X;
	case BTN_START:
		return KEY_ENTER;
	case BTN_MODE:
	case BTN_SELECT:
		return KEY_ESC;
	default:
		return 0;
	}
}

static int axis_rel(int val, const struct input_absinfo *a)
{
	int mid, span, d, ad, dead, step;

	if (!a)
		return 0;
	mid = a->minimum + (a->maximum - a->minimum) / 2;
	span = (a->maximum - a->minimum) / 2;
	if (span < 1)
		return 0;
	d = val - mid;
	ad = d < 0 ? -d : d;
	dead = a->flat > 0 ? a->flat * 2 : span / 8;
	if (ad < dead)
		return 0;
	step = d * 8 / span;
	if (step > 12)
		step = 12;
	if (step < -12)
		step = -12;
	if (step == 0)
		step = d > 0 ? 1 : -1;
	return step;
}

static void stick_mouse(int dst, int vx, int vy, int vrx, int vry,
			int have_x, int have_y, int have_rx, int have_ry,
			const struct input_absinfo *absx,
			const struct input_absinfo *absy,
			const struct input_absinfo *absrx,
			const struct input_absinfo *absry)
{
	int dx = 0, dy = 0;

	if (have_x)
		dx += axis_rel(vx, absx);
	if (have_y)
		dy += axis_rel(vy, absy);
	if (have_rx)
		dx += axis_rel(vrx, absrx);
	if (have_ry)
		dy += axis_rel(vry, absry);
	if (!dx && !dy)
		return;
	if (dx)
		emit(dst, EV_REL, REL_X, dx);
	if (dy)
		emit(dst, EV_REL, REL_Y, dy);
	emit(dst, EV_SYN, SYN_REPORT, 0);
}

static void release_pad(int src, int dst, int grabbed)
{
	if (dst >= 0) {
		ioctl(dst, UI_DEV_DESTROY);
		close(dst);
	}
	if (src >= 0) {
		if (grabbed)
			ioctl(src, EVIOCGRAB, (void *)0);
		close(src);
	}
}

int main(int argc, char **argv)
{
	char path[320];
	int src = -1, dst = -1, grabbed = 0;
	struct input_absinfo absx, absy, absrx, absry;
	int have_x = 0, have_y = 0, have_rx = 0, have_ry = 0;
	int vx = 0, vy = 0, vrx = 0, vry = 0;
	int click_held = 0;
	int child_rc = 0;
	int hat_x = 0;
	int hat_y = 0;

	signal(SIGTERM, on_sig);
	signal(SIGINT, on_sig);
	signal(SIGHUP, on_sig);

	if (find_virtpad(path, sizeof(path)) != 0) {
		fprintf(stderr, "pico8-splore-pad: no virtual controller\n");
		return 1;
	}
	src = open(path, O_RDONLY);
	if (src < 0) {
		perror(path);
		return 1;
	}
	if (ioctl(src, EVIOCGRAB, (void *)1) == 0)
		grabbed = 1;
	else
		fprintf(stderr, "pico8-splore-pad: grab failed (%s), continuing\n",
			strerror(errno));

	if (ioctl(src, EVIOCGABS(ABS_X), &absx) == 0) {
		have_x = 1;
		vx = absx.value;
	}
	if (ioctl(src, EVIOCGABS(ABS_Y), &absy) == 0) {
		have_y = 1;
		vy = absy.value;
	}
	if (ioctl(src, EVIOCGABS(ABS_RX), &absrx) == 0) {
		have_rx = 1;
		vrx = absrx.value;
	}
	if (ioctl(src, EVIOCGABS(ABS_RY), &absry) == 0) {
		have_ry = 1;
		vry = absry.value;
	}

	dst = setup_uinput();
	if (dst < 0) {
		perror("uinput");
		release_pad(src, -1, grabbed);
		return 1;
	}

	if (argc > 1) {
		child_pid = fork();
		if (child_pid == 0) {
			close(src);
			close(dst);
			execvp(argv[1], argv + 1);
			perror(argv[1]);
			_exit(127);
		}
		if (child_pid < 0) {
			perror("fork");
			release_pad(src, dst, grabbed);
			return 1;
		}
	}

	fprintf(stderr, "pico8-splore-pad: mapping %s -> uinput%s\n",
		path, grabbed ? " (grabbed)" : "");

	while (running) {
		fd_set rfds;
		struct timeval tv;
		int s;
		int st;

		if (child_pid > 0) {
			pid_t w = waitpid(child_pid, &st, WNOHANG);

			if (w == child_pid) {
				child_rc = WIFEXITED(st) ? WEXITSTATUS(st) : 1;
				child_pid = 0;
				break;
			}
		}

		FD_ZERO(&rfds);
		FD_SET(src, &rfds);
		tv.tv_sec = 0;
		tv.tv_usec = 16000;
		s = select(src + 1, &rfds, NULL, NULL, &tv);
		if (s < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		if (s > 0 && FD_ISSET(src, &rfds)) {
			struct input_event ev;
			ssize_t n = read(src, &ev, sizeof(ev));
			int key;

			if (n < 0) {
				if (errno == EINTR)
					continue;
				break;
			}
			if (n == (ssize_t)sizeof(ev)) {
				if (ev.type == EV_KEY) {
					if (ev.code == BTN_TR || ev.code == BTN_TR2 ||
					    ev.code == BTN_THUMBR) {
						int down = ev.value ? 1 : 0;

						if (down != click_held) {
							click_held = down;
							emit_key(dst, BTN_LEFT, down);
						}
					} else if (ev.code == BTN_TL2 && ev.value == 1) {
						emit(dst, EV_REL, REL_WHEEL, 1);
						emit(dst, EV_SYN, SYN_REPORT, 0);
					} else if (ev.code == BTN_TL && ev.value == 1) {
						emit(dst, EV_REL, REL_WHEEL, -1);
						emit(dst, EV_SYN, SYN_REPORT, 0);
					} else {
						key = map_key(ev.code);
						if (key && ev.value != 2)
							emit_key(dst, key, ev.value);
					}
				} else if (ev.type == EV_ABS) {
					if (ev.code == ABS_HAT0X)
						set_hat(dst, &hat_x, ev.value, KEY_LEFT, KEY_RIGHT);
					else if (ev.code == ABS_HAT0Y)
						set_hat(dst, &hat_y, ev.value, KEY_UP, KEY_DOWN);
					else if (ev.code == ABS_X && have_x)
						vx = ev.value;
					else if (ev.code == ABS_Y && have_y)
						vy = ev.value;
					else if (ev.code == ABS_RX && have_rx)
						vrx = ev.value;
					else if (ev.code == ABS_RY && have_ry)
						vry = ev.value;
				}
			}
		}
		stick_mouse(dst, vx, vy, vrx, vry, have_x, have_y, have_rx, have_ry,
			    &absx, &absy, &absrx, &absry);
	}

	if (child_pid > 0) {
		kill(child_pid, SIGTERM);
		waitpid(child_pid, NULL, 0);
		child_pid = 0;
	}
	release_pad(src, dst, grabbed);
	return child_rc;
}
