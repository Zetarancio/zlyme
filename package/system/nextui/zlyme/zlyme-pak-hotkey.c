/*
 * Watch MENU+Start while one pak process group lives.
 * nextui-session passes the setsid child pid (also the pgid). SIGTERM the
 * group, then SIGKILL after a short grace. Do not touch nextui.elf.
 *
 * js0 buttons 9/10 match platform.h. Also watch retrogame_joypad evdev
 * (BTN_MODE + BTN_START) if joydev is busy or missing.
 */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/joystick.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define JOY_START 9
#define JOY_MENU 10
#define GRACE_US 1500000
#define PAD_NAME "retrogame_joypad"

static int open_js(void)
{
	static const char *const cands[] = {
		"/dev/input/js0",
		"/dev/js0",
		NULL,
	};
	int i, fd;

	for (i = 0; cands[i]; i++) {
		fd = open(cands[i], O_RDONLY | O_NONBLOCK);
		if (fd >= 0)
			return fd;
	}
	return -1;
}

static int open_pad_evdev(void)
{
	DIR *dir;
	struct dirent *ent;
	int found = -1;

	dir = opendir("/dev/input");
	if (!dir)
		return -1;
	while ((ent = readdir(dir))) {
		char path[64];
		char name[256];
		int fd;

		if (strncmp(ent->d_name, "event", 5) != 0)
			continue;
		snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
		fd = open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK);
		if (fd < 0)
			continue;
		memset(name, 0, sizeof(name));
		if (ioctl(fd, EVIOCGNAME(sizeof(name) - 1), name) < 0) {
			close(fd);
			continue;
		}
		if (strcmp(name, PAD_NAME) != 0) {
			close(fd);
			continue;
		}
		found = fd;
		break;
	}
	closedir(dir);
	return found;
}

static void kill_pak(pid_t pgid)
{
	kill(-pgid, SIGTERM);
	usleep(GRACE_US);
	kill(-pgid, SIGKILL);
}

int main(int argc, char **argv)
{
	pid_t pgid;
	int js_fd, ev_fd, menu = 0, start = 0, nfd = 0;
	struct pollfd pf[2];

	if (argc < 2)
		return 1;
	pgid = (pid_t)atoi(argv[1]);
	if (pgid <= 1)
		return 1;

	js_fd = open_js();
	ev_fd = open_pad_evdev();
	if (js_fd < 0 && ev_fd < 0)
		return 1;

	if (js_fd >= 0) {
		pf[nfd].fd = js_fd;
		pf[nfd].events = POLLIN;
		nfd++;
	}
	if (ev_fd >= 0) {
		pf[nfd].fd = ev_fd;
		pf[nfd].events = POLLIN;
		nfd++;
	}

	while (poll(pf, (nfds_t)nfd, -1) >= 0) {
		int i;

		for (i = 0; i < nfd; i++) {
			if (!(pf[i].revents & POLLIN))
				continue;
			if (pf[i].fd == js_fd) {
				struct js_event e;

				while (read(js_fd, &e, sizeof(e)) == (ssize_t)sizeof(e)) {
					if (e.type & JS_EVENT_INIT)
						continue;
					if ((e.type & ~JS_EVENT_INIT) != JS_EVENT_BUTTON)
						continue;
					if (e.number == JOY_MENU)
						menu = e.value;
					else if (e.number == JOY_START)
						start = e.value;
				}
			} else if (pf[i].fd == ev_fd) {
				struct input_event ev;

				while (read(ev_fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
					if (ev.type != EV_KEY)
						continue;
					if (ev.code == BTN_MODE)
						menu = ev.value != 0;
					else if (ev.code == BTN_START)
						start = ev.value != 0;
				}
			}
		}
		if (menu && start) {
			kill_pak(pgid);
			break;
		}
	}

	if (js_fd >= 0)
		close(js_fd);
	if (ev_fd >= 0)
		close(ev_fd);
	(void)errno;
	return 0;
}
