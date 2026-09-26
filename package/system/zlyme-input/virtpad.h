#ifndef ZLYME_VIRTPAD_H
#define ZLYME_VIRTPAD_H

/*
 * Application-facing InputPlumber xb360 target.
 * Live Flip identity: name "Microsoft X-Box 360 pad",
 * BUS_USB 045e:028e version 0001, sysfs under /devices/virtual/.
 * A physical pad, including the grabbed Miyoo Flip Gamepad, is not this.
 */
#include <linux/input.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static inline int zlyme_is_virtpad(int fd, const char *event_basename)
{
	struct input_id id;
	char name[256];
	char sys[320];
	char link[512];
	ssize_t n;

	if (!event_basename || strlen(event_basename) > 16)
		return 0;
	memset(name, 0, sizeof name);
	if (ioctl(fd, EVIOCGNAME(sizeof name - 1), name) < 0)
		return 0;
	if (strcmp(name, "Microsoft X-Box 360 pad") != 0)
		return 0;
	if (ioctl(fd, EVIOCGID, &id) < 0)
		return 0;
	if (id.bustype != BUS_USB || id.vendor != 0x045e ||
	    id.product != 0x028e || id.version != 0x0001)
		return 0;
	/* eventN/device is a short relative link. The class node itself
	 * points at /devices/virtual/ for an InputPlumber target. */
	snprintf(sys, sizeof sys, "/sys/class/input/%s", event_basename);
	n = readlink(sys, link, sizeof link - 1);
	if (n < 0)
		return 0;
	link[n] = '\0';
	return strstr(link, "/devices/virtual/") != NULL;
}

#endif
