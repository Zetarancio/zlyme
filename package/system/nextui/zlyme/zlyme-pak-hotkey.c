/*
 * Watch MENU+START while one pak process group lives.
 * nextui-session passes the setsid child pid (also the pgid). SIGTERM the
 * group, then SIGKILL after a short grace. Do not touch nextui.elf.
 *
 * The chord is read from each InputPlumber xb360 target. MENU+START on
 * any one virtual controller exits. Buttons from two controllers do not
 * combine. js0 and the physical Miyoo Flip Gamepad are not sources.
 */
#include "hotkey_logic.h"
#include "virtpad.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <unistd.h>

#define GRACE_US 1500000
#define MAX_PADS 8

struct app_pad {
	int fd;
	int menu;
	int start;
	char node[32];
};

static int pad_find(struct app_pad *pads, int n, const char *node)
{
	int i;

	for (i = 0; i < n; i++)
		if (strcmp(pads[i].node, node) == 0)
			return i;
	return -1;
}

static void drop_fd(struct app_pad *pads, int *n, int fd)
{
	int i;

	for (i = 0; i < *n; i++) {
		if (pads[i].fd != fd)
			continue;
		zlyme_hotkey_reset(&pads[i].menu, &pads[i].start);
		close(pads[i].fd);
		pads[i] = pads[*n - 1];
		(*n)--;
		return;
	}
}

static void scan_pads(struct app_pad *pads, int *n)
{
	DIR *dir;
	struct dirent *ent;

	dir = opendir("/dev/input");
	if (!dir)
		return;
	while ((ent = readdir(dir))) {
		char path[320];
		int fd;

		size_t len;

		if (strncmp(ent->d_name, "event", 5) != 0)
			continue;
		len = strlen(ent->d_name);
		if (len == 0 || len >= sizeof pads[0].node)
			continue;
		if (pad_find(pads, *n, ent->d_name) >= 0)
			continue;
		if (*n >= MAX_PADS)
			break;
		snprintf(path, sizeof path, "/dev/input/%s", ent->d_name);
		fd = open(path, O_RDONLY | O_CLOEXEC | O_NONBLOCK);
		if (fd < 0)
			continue;
		if (!zlyme_is_virtpad(fd, ent->d_name)) {
			close(fd);
			continue;
		}
		pads[*n].fd = fd;
		zlyme_hotkey_reset(&pads[*n].menu, &pads[*n].start);
		memcpy(pads[*n].node, ent->d_name, len + 1);
		(*n)++;
	}
	closedir(dir);
}

static void kill_pak(pid_t pgid)
{
	kill(-pgid, SIGTERM);
	usleep(GRACE_US);
	kill(-pgid, SIGKILL);
}

static int read_pad(struct app_pad *pad)
{
	struct input_event ev;

	while (read(pad->fd, &ev, sizeof ev) == (ssize_t)sizeof ev) {
		if (ev.type != EV_KEY)
			continue;
		if (zlyme_hotkey_apply(&pad->menu, &pad->start, ev.code, ev.value != 0))
			return 1;
	}
	return 0;
}

static void drain_inotify(int fd)
{
	char buf[4096];

	while (read(fd, buf, sizeof buf) > 0)
		;
}

int main(int argc, char **argv)
{
	pid_t pgid;
	struct app_pad pads[MAX_PADS];
	int npads = 0;
	int ino;

	if (argc < 2)
		return 1;
	pgid = (pid_t)atoi(argv[1]);
	if (pgid <= 1)
		return 1;

	ino = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
	scan_pads(pads, &npads);
	if (ino >= 0) {
		if (inotify_add_watch(ino, "/dev/input",
				      IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO) < 0) {
			close(ino);
			ino = -1;
		} else {
			scan_pads(pads, &npads);
		}
	}
	if (ino < 0 && npads == 0)
		return 1;

	while (1) {
		struct pollfd pf[MAX_PADS + 1];
		int nfd = 0;
		int i;
		int fire = 0;

		if (ino >= 0) {
			pf[nfd].fd = ino;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		for (i = 0; i < npads; i++) {
			pf[nfd].fd = pads[i].fd;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		if (nfd == 0)
			break;
		if (poll(pf, (nfds_t)nfd, -1) < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		for (i = 0; i < nfd; i++) {
			int j;

			if (pf[i].fd == ino && (pf[i].revents & POLLIN)) {
				drain_inotify(ino);
				scan_pads(pads, &npads);
			}
			for (j = 0; j < npads; j++) {
				if (pads[j].fd != pf[i].fd)
					continue;
				if (pf[i].revents & POLLIN && read_pad(&pads[j]))
					fire = 1;
				if (pf[i].revents & (POLLHUP | POLLERR | POLLNVAL))
					drop_fd(pads, &npads, pf[i].fd);
				break;
			}
		}
		if (fire) {
			kill_pak(pgid);
			break;
		}
	}

	while (npads > 0)
		drop_fd(pads, &npads, pads[0].fd);
	if (ino >= 0)
		close(ino);
	return 0;
}
