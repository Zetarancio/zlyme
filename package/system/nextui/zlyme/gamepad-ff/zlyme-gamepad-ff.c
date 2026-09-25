#include "ff_gain.h"

#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>

#define PAD_NAME "Miyoo Flip Gamepad"
#define GAIN_FILE "/storage/.config/zlyme/miyoo-flip-gamepad/rumble.config"

static int has_ff(int fd, int code)
{
	unsigned long bits[(FF_MAX / (sizeof(unsigned long) * 8)) + 1];
	unsigned shift = sizeof(unsigned long) * 8;

	memset(bits, 0, sizeof(bits));
	if (ioctl(fd, EVIOCGBIT(EV_FF, sizeof(bits)), bits) < 0)
		return 0;
	return (bits[code / shift] >> (code % shift)) & 1UL;
}

static int open_pad(void)
{
	DIR *dir = opendir("/dev/input");
	struct dirent *de;

	if (!dir)
		return -1;
	while ((de = readdir(dir))) {
		char path[64];
		char name[128];
		int fd;

		if (strncmp(de->d_name, "event", 5) != 0)
			continue;
		snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);
		fd = open(path, O_RDWR | O_CLOEXEC);
		if (fd < 0)
			continue;
		memset(name, 0, sizeof(name));
		if (ioctl(fd, EVIOCGNAME(sizeof(name) - 1), name) >= 0 &&
		    strcmp(name, PAD_NAME) == 0 &&
		    has_ff(fd, FF_RUMBLE) && has_ff(fd, FF_GAIN)) {
			closedir(dir);
			return fd;
		}
		close(fd);
	}
	closedir(dir);
	return -1;
}

static int set_gain(int fd, int pct)
{
	struct input_event ev;
	int value = ff_gain_value(pct);

	if (value < 0)
		return -1;
	memset(&ev, 0, sizeof(ev));
	ev.type = EV_FF;
	ev.code = FF_GAIN;
	ev.value = value;
	return write(fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev) ? 0 : -1;
}

static int do_restore(int fd)
{
	FILE *f = fopen(GAIN_FILE, "r");
	char body[128];
	int pct = 100;
	size_t n;

	if (!f)
		return 0;
	n = fread(body, 1, sizeof(body) - 1, f);
	body[n] = 0;
	fclose(f);
	if (ff_parse_gain(body, &pct)) {
		fprintf(stderr, "rumble.config invalid; using 100\n");
		pct = 100;
	}
	return set_gain(fd, pct);
}

static int do_test(int fd)
{
	struct ff_effect e;
	struct input_event ev;

	memset(&e, 0, sizeof(e));
	e.type = FF_RUMBLE;
	e.id = -1;
	e.u.rumble.strong_magnitude = 0xffff;
	e.replay.length = 250;
	if (ioctl(fd, EVIOCSFF, &e) < 0)
		return -1;
	memset(&ev, 0, sizeof(ev));
	ev.type = EV_FF;
	ev.code = e.id;
	ev.value = 1;
	if (write(fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev)) {
		ioctl(fd, EVIOCRMFF, e.id);
		return -1;
	}
	usleep(300000);
	ev.value = 0;
	if (write(fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev)) {
		ioctl(fd, EVIOCRMFF, e.id);
		return -1;
	}
	ioctl(fd, EVIOCRMFF, e.id);
	return 0;
}

int main(int argc, char **argv)
{
	int fd, pct, rc;

	if (argc < 2) {
		fprintf(stderr, "usage: %s gain PCT | restore | test\n", argv[0]);
		return 2;
	}
	fd = open_pad();
	if (fd < 0) {
		fprintf(stderr, "Miyoo Flip Gamepad FF is unavailable\n");
		return 1;
	}
	if (strcmp(argv[1], "gain") == 0 && argc == 3) {
		pct = atoi(argv[2]);
		rc = set_gain(fd, pct);
	} else if (strcmp(argv[1], "restore") == 0) {
		rc = do_restore(fd);
	} else if (strcmp(argv[1], "test") == 0) {
		rc = do_test(fd);
	} else {
		rc = 2;
	}
	close(fd);
	return rc == 0 ? 0 : 1;
}
