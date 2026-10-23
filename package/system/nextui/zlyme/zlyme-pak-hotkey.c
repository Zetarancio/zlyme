/*
 * Watch MENU+START while one pak process group lives.
 * nextui-session passes the spawn waiter and its published start time.
 * The helper retains a pidfd and asks that exact waiter to stop the
 * owned session. The waiter performs bounded TERM/KILL cleanup. The
 * frontend group is never a signal target.
 *
 * The chord is read from each InputPlumber xb360 target. MENU+START on
 * any one virtual controller exits. Buttons from two controllers do not
 * combine. The physical pad and js0 are not sources.
 */
#include "hotkey_logic.h"
#include "virtpad.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/syscall.h>

#define MAX_PADS 8

static FILE *trace_fp;

static void trace_open(void)
{
	const char *on;
	const char *path;

	on = getenv("ZLYME_PAK_TRACE");
	if (!on || strcmp(on, "1") != 0)
		return;
	path = getenv("ZLYME_PAK_TRACE_LOG");
	if (!path || path[0] == '\0')
		path = "/tmp/zlyme-pak-trace.txt";
	trace_fp = fopen(path, "a");
	if (trace_fp)
		setvbuf(trace_fp, NULL, _IOLBF, 0);
}

static void trace_msg(const char *fmt, ...)
{
	va_list ap;

	if (!trace_fp)
		return;
	va_start(ap, fmt);
	vfprintf(trace_fp, fmt, ap);
	va_end(ap);
	fputc('\n', trace_fp);
}

struct app_pad {
	int fd;
	int menu;
	int start;
	char node[32];
};

struct target_info {
	pid_t pgid;
	pid_t sid;
	char state;
	unsigned long long starttime;
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
		trace_msg("pad %s", pads[*n].node);
		(*n)++;
	}
	closedir(dir);
}

static int target_info(pid_t pid, struct target_info *info)
{
	char path[64];
	char buf[512];
	char *rest;
	char *save = NULL;
	char *token;
	char *end;
	ssize_t n;
	long value;
	int field = 0;
	int fd;

	snprintf(path, sizeof path, "/proc/%d/stat", (int)pid);
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return 0;
	n = read(fd, buf, sizeof buf - 1);
	close(fd);
	if (n <= 0)
		return 0;
	buf[n] = '\0';
	rest = strrchr(buf, ')');
	if (!rest)
		return 0;
	memset(info, 0, sizeof *info);
	for (token = strtok_r(rest + 1, " \t\r\n", &save);
	     token;
	     token = strtok_r(NULL, " \t\r\n", &save), field++) {
		switch (field) {
		case 0:
			if (token[0] == '\0' || token[1] != '\0')
				return 0;
			info->state = token[0];
			break;
		case 2:
		case 3:
			errno = 0;
			value = strtol(token, &end, 10);
			if (errno != 0 || end == token || *end != '\0')
				return 0;
			if (field == 2)
				info->pgid = (pid_t)value;
			else
				info->sid = (pid_t)value;
			break;
		case 19:
			errno = 0;
			info->starttime = strtoull(token, &end, 10);
			if (errno != 0 || end == token || *end != '\0')
				return 0;
			return 1;
		default:
			break;
		}
	}
	return 0;
}

static int parse_pid(const char *text, pid_t *pid)
{
	char *end;
	long value;

	errno = 0;
	value = strtol(text, &end, 10);
	if (errno != 0 || end == text || *end != '\0' || value <= 1)
		return 0;
	*pid = (pid_t)value;
	return (long)*pid == value;
}

static int parse_starttime(const char *text, unsigned long long *starttime)
{
	char *end;
	unsigned long long value;

	errno = 0;
	value = strtoull(text, &end, 10);
	if (errno != 0 || end == text || *end != '\0' || value == 0)
		return 0;
	*starttime = value;
	return 1;
}

static int open_waiter(pid_t waiter, unsigned long long starttime)
{
#if defined(SYS_pidfd_open) && defined(SYS_pidfd_send_signal)
	struct target_info info;
	int fd;

	if (!target_info(waiter, &info) ||
	    !zlyme_hotkey_same_waiter(1, info.state, info.starttime, starttime))
		return -1;
	fd = (int)syscall(SYS_pidfd_open, waiter, 0);
	if (fd < 0)
		return -1;
	if (!target_info(waiter, &info) ||
	    !zlyme_hotkey_same_waiter(1, info.state, info.starttime, starttime)) {
		close(fd);
		return -1;
	}
	return fd;
#else
	(void)waiter;
	(void)starttime;
	errno = ENOSYS;
	return -1;
#endif
}

static int stop_pak(int waiter_fd, pid_t waiter, pid_t leader)
{
#if defined(SYS_pidfd_send_signal)
	int rc;

	rc = (int)syscall(SYS_pidfd_send_signal, waiter_fd, SIGTERM, NULL, 0);
	trace_msg("stop waiter=%d leader=%d rc=%d errno=%d", (int)waiter,
		  (int)leader, rc, rc < 0 ? errno : 0);
	return rc == 0 ? 0 : 1;
#else
	(void)waiter_fd;
	(void)waiter;
	(void)leader;
	return 1;
#endif
}

static int read_pad(struct app_pad *pad)
{
	struct input_event ev;

	while (read(pad->fd, &ev, sizeof ev) == (ssize_t)sizeof ev) {
		int prev_menu;
		int prev_start;

		if (ev.type != EV_KEY)
			continue;
		prev_menu = pad->menu;
		prev_start = pad->start;
		if (zlyme_hotkey_apply(&pad->menu, &pad->start, ev.code, ev.value != 0)) {
			if (pad->menu != prev_menu || pad->start != prev_start)
				trace_msg("chord %s menu=%d start=%d", pad->node,
					  pad->menu, pad->start);
			return 1;
		}
		if ((ev.code == BTN_MODE || ev.code == BTN_START) &&
		    (pad->menu != prev_menu || pad->start != prev_start))
			trace_msg("chord %s menu=%d start=%d", pad->node,
				  pad->menu, pad->start);
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
	pid_t waiter;
	pid_t leader;
	unsigned long long waiter_starttime;
	unsigned long long leader_starttime;
	struct app_pad pads[MAX_PADS];
	int npads = 0;
	int ino;
	int waiter_fd;
	int result = 0;

	if (argc != 5 ||
	    !parse_pid(argv[1], &waiter) ||
	    !parse_starttime(argv[2], &waiter_starttime) ||
	    !parse_pid(argv[3], &leader) ||
	    !parse_starttime(argv[4], &leader_starttime) ||
	    waiter == leader)
		return 1;
	waiter_fd = open_waiter(waiter, waiter_starttime);
	if (waiter_fd < 0)
		return 1;

	trace_open();
	trace_msg("hotkey pid=%d waiter=%d leader=%d leader_start=%llu",
		  (int)getpid(), (int)waiter, (int)leader, leader_starttime);
#ifdef ZLYME_TESTING
	if (getenv("ZLYME_TEST_STOP_NOW")) {
		result = stop_pak(waiter_fd, waiter, leader);
		close(waiter_fd);
		if (trace_fp)
			fclose(trace_fp);
		return result;
	}
#endif

	ino = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
	if (ino < 0)
		trace_msg("inotify unavailable");
	scan_pads(pads, &npads);
	if (ino >= 0) {
		if (inotify_add_watch(ino, "/dev/input",
				      IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO) < 0) {
			trace_msg("inotify unavailable");
			close(ino);
			ino = -1;
		} else {
			scan_pads(pads, &npads);
		}
	}
	if (npads == 0)
		trace_msg("no virtual pad");
	if (ino < 0 && npads == 0) {
		close(waiter_fd);
		return 1;
	}

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
			result = stop_pak(waiter_fd, waiter, leader);
			break;
		}
	}

	while (npads > 0)
		drop_fd(pads, &npads, pads[0].fd);
	if (ino >= 0)
		close(ino);
	close(waiter_fd);
	if (trace_fp)
		fclose(trace_fp);
	return result;
}
