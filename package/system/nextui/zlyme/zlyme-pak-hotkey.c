/*
 * Watch MENU+Start on the Flip joypad while one pak process group lives.
 * nextui-session passes the setsid child pid (also the pgid). SIGTERM the
 * group, then SIGKILL after a short grace. Do not touch nextui.elf.
 */
#include <errno.h>
#include <fcntl.h>
#include <linux/joystick.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define JOY_START 9
#define JOY_MENU 10
#define GRACE_US 1500000

static int open_js(void)
{
	static const char *const cands[] = {
		"/dev/input/js0",
		"/dev/js0",
		NULL,
	};
	int i, fd;

	for (i = 0; cands[i]; i++) {
		fd = open(cands[i], O_RDONLY);
		if (fd >= 0)
			return fd;
	}
	return -1;
}

int main(int argc, char **argv)
{
	pid_t pgid;
	int fd, menu = 0, start = 0;
	struct js_event e;

	if (argc < 2)
		return 1;
	pgid = (pid_t)atoi(argv[1]);
	if (pgid <= 1)
		return 1;

	fd = open_js();
	if (fd < 0)
		return 1;

	while (read(fd, &e, sizeof(e)) == (ssize_t)sizeof(e)) {
		if (e.type & JS_EVENT_INIT)
			continue;
		if ((e.type & ~JS_EVENT_INIT) != JS_EVENT_BUTTON)
			continue;
		if (e.number == JOY_MENU)
			menu = e.value;
		else if (e.number == JOY_START)
			start = e.value;
		if (menu && start) {
			kill(-pgid, SIGTERM);
			usleep(GRACE_US);
			kill(-pgid, SIGKILL);
			close(fd);
			return 0;
		}
	}
	close(fd);
	(void)errno;
	return 0;
}
