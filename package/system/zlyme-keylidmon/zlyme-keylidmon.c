/*
 * Volume, MENU+vol brightness, and lid sleep while a pak owns the screen.
 * NextUI already applies volume/brightness in PWR_update; do not steal
 * those keys while nextui.elf is running. Stay the msettings shm host.
 */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#include "msettings.h"
#include "virtpad.h"

#define VOL_NAME "gpio-keys-volume"
#define HALL_NAME "gpio-keys-hall"
#define PWR_NAME "rk805 pwrkey"
#define MAX_PADS 8
#define BLANK_PATH "/sys/class/backlight/backlight/bl_power"
#define BRIGHTNESS_PATH "/sys/class/backlight/backlight/brightness"
#define VOLUME_MAX 20
#define BRIGHTNESS_MAX 10
#define FB_BLANK_UNBLANK 0
#define FB_BLANK_POWERDOWN 4
/* Same window NextUI uses after resume (pwr.resume_tick). */
#define POWER_RESUME_GUARD_MS 1000

/* 0 means no guard. Armed only after radios resume returns. */
static unsigned long long power_ignore_until_ms;

static unsigned long long monotonic_ms(void)
{
	struct timespec ts;

	if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
		return 0;
	return (unsigned long long)ts.tv_sec * 1000ULL +
	       (unsigned long long)ts.tv_nsec / 1000000ULL;
}

static volatile sig_atomic_t quit;

static void on_term(int sig)
{
	(void)sig;
	quit = 1;
}

static int menu_owns_keys(void)
{
	DIR *dir;
	struct dirent *ent;
	int alive = 0;

	dir = opendir("/proc");
	if (!dir)
		return 0;
	while ((ent = readdir(dir))) {
		char path[320];
		char comm[64];
		FILE *f;

		if (ent->d_name[0] < '1' || ent->d_name[0] > '9')
			continue;
		snprintf(path, sizeof(path), "/proc/%s/comm", ent->d_name);
		f = fopen(path, "r");
		if (!f)
			continue;
		if (fgets(comm, sizeof(comm), f)) {
			if (strncmp(comm, "nextui.elf", 10) == 0 ||
			    strncmp(comm, "minui.elf", 9) == 0 ||
			    strncmp(comm, "settings.elf", 12) == 0)
				alive = 1;
		}
		fclose(f);
		if (alive)
			break;
	}
	closedir(dir);
	return alive;
}

static int open_by_name(const char *want)
{
	DIR *dir;
	struct dirent *ent;
	int found = -1;

	dir = opendir("/dev/input");
	if (!dir)
		return -1;
	while ((ent = readdir(dir))) {
		char path[320];
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
		if (strcmp(name, want) != 0) {
			close(fd);
			continue;
		}
		found = fd;
		break;
	}
	closedir(dir);
	return found;
}

static void write_int(const char *path, int v)
{
	char buf[16];
	int n, fd;

	fd = open(path, O_WRONLY | O_CLOEXEC);
	if (fd < 0)
		return;
	n = snprintf(buf, sizeof(buf), "%d\n", v);
	if (n > 0)
		write(fd, buf, (size_t)n);
	close(fd);
}

static void screen_off(void)
{
	write_int(BLANK_PATH, FB_BLANK_POWERDOWN);
	write_int(BRIGHTNESS_PATH, 0);
}

static void screen_on(void)
{
	write_int(BLANK_PATH, FB_BLANK_UNBLANK);
	SetBrightness(GetBrightness());
}

/* Lid: screen + radios off, wait for open. Power uses mem. */
static void do_lid_sleep(int hall_fd)
{
	struct pollfd p = { .fd = hall_fd, .events = POLLIN };
	struct input_event ev;

	if (menu_owns_keys() || hall_fd < 0)
		return;
	system("/usr/sbin/zlyme-radios pre >/dev/null 2>&1");
	screen_off();
	while (!quit) {
		if (poll(&p, 1, 300) < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		if (!(p.revents & POLLIN))
			continue;
		while (read(hall_fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
			if (ev.type == EV_SW && ev.code == SW_LID && ev.value == 0)
				goto wake;
		}
	}
wake:
	screen_on();
	system("/usr/sbin/zlyme-radios resume >/dev/null 2>&1");
}

static void do_mem_sleep(void)
{
	if (menu_owns_keys())
		return;
	system("/usr/sbin/zlyme-radios pre >/dev/null 2>&1");
	if (access("/usr/share/nextui/bin/suspend", X_OK) == 0)
		system("/usr/share/nextui/bin/suspend");
	else
		system("echo mem > /sys/power/state");
	system("/usr/sbin/zlyme-radios resume >/dev/null 2>&1");
	/*
	 * The wake press is delivered as KEY_POWER=1 after mem returns.
	 * Arm the ignore window only once radio recovery has finished,
	 * so a resume that takes longer than the window cannot expire
	 * before that queued press is read.
	 */
	{
		unsigned long long now = monotonic_ms();

		power_ignore_until_ms = now ? now + POWER_RESUME_GUARD_MS : 0;
	}
}

static void apply_vol(int up)
{
	int v = GetVolume();

	if (up && v < VOLUME_MAX)
		SetVolume(v + 1);
	else if (!up && v > 0)
		SetVolume(v - 1);
}

static void apply_bri(int up)
{
	int v = GetBrightness();

	if (up && v < BRIGHTNESS_MAX)
		SetBrightness(v + 1);
	else if (!up && v > 0)
		SetBrightness(v - 1);
}

struct menu_pad {
	int fd;
	int down;
	char node[32];
};

static int pad_find(struct menu_pad *pads, int n, const char *node)
{
	int i;

	for (i = 0; i < n; i++)
		if (strcmp(pads[i].node, node) == 0)
			return i;
	return -1;
}

static int any_menu(struct menu_pad *pads, int n)
{
	int i;

	for (i = 0; i < n; i++)
		if (pads[i].down)
			return 1;
	return 0;
}

static void drop_menu_fd(struct menu_pad *pads, int *n, int fd)
{
	int i;

	for (i = 0; i < *n; i++) {
		if (pads[i].fd != fd)
			continue;
		close(pads[i].fd);
		pads[i] = pads[*n - 1];
		(*n)--;
		return;
	}
}

/* MENU for brightness comes from each virtual xb360 target. Volume,
 * power, and the lid stay on their own devices. */
static void scan_menu_pads(struct menu_pad *pads, int *n)
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
		pads[*n].down = 0;
		memcpy(pads[*n].node, ent->d_name, len + 1);
		(*n)++;
	}
	closedir(dir);
}

static void drain_inotify(int fd)
{
	char buf[4096];

	while (read(fd, buf, sizeof buf) > 0)
		;
}

/* Platform directory is ZLYME_NEXTUI_PLATFORM. my355 remains the
 * fallback when device.conf is missing. */
static void zlyme_set_userdata_path(void)
{
	FILE *f;
	char line[160];
	char plat[64];
	char path[160];
	char *p;
	size_t n;

	if (getenv("USERDATA_PATH"))
		return;
	plat[0] = '\0';
	f = fopen("/usr/share/zlyme/device.conf", "r");
	if (f) {
		while (fgets(line, sizeof(line), f)) {
			if (strncmp(line, "ZLYME_NEXTUI_PLATFORM=", 22) != 0)
				continue;
			p = line + 22;
			while (*p == ' ' || *p == '\t' || *p == '\'' || *p == '"')
				p++;
			n = strcspn(p, "\r\n'\"");
			if (n > 0 && n < sizeof(plat)) {
				memcpy(plat, p, n);
				plat[n] = '\0';
			}
			break;
		}
		fclose(f);
	}
	if (plat[0] == '\0')
		snprintf(plat, sizeof(plat), "my355");
	snprintf(path, sizeof(path), "/storage/.config/nextui/%s", plat);
	setenv("USERDATA_PATH", path, 0);
}

int main(void)
{
	struct menu_pad pads[MAX_PADS];
	int npads = 0;
	int vol_fd, hall_fd, pwr_fd, ino;
	int grabbed = 0;
	int menu = 0;
	struct sigaction sa = {0};

	sa.sa_handler = on_term;
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);

	zlyme_set_userdata_path();
	InitSettings();

	vol_fd = open_by_name(VOL_NAME);
	hall_fd = open_by_name(HALL_NAME);
	pwr_fd = open_by_name(PWR_NAME);
	ino = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
	scan_menu_pads(pads, &npads);
	if (ino >= 0) {
		if (inotify_add_watch(ino, "/dev/input",
				      IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO) < 0) {
			close(ino);
			ino = -1;
		} else {
			scan_menu_pads(pads, &npads);
		}
	}
	if (vol_fd < 0 && hall_fd < 0 && pwr_fd < 0)
		return 1;

	while (!quit) {
		struct pollfd pf[MAX_PADS + 4];
		int nfd = 0;
		int in_game = !menu_owns_keys();
		int i;

		if (vol_fd >= 0 && grabbed != in_game) {
			int g = in_game ? 1 : 0;
			ioctl(vol_fd, EVIOCGRAB, g);
			grabbed = in_game;
		}

		for (i = 0; i < npads; i++) {
			pf[nfd].fd = pads[i].fd;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		if (vol_fd >= 0) {
			pf[nfd].fd = vol_fd;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		if (hall_fd >= 0) {
			pf[nfd].fd = hall_fd;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		if (pwr_fd >= 0) {
			pf[nfd].fd = pwr_fd;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		if (ino >= 0) {
			pf[nfd].fd = ino;
			pf[nfd].events = POLLIN;
			nfd++;
		}
		if (nfd == 0)
			break;

		if (poll(pf, (nfds_t)nfd, 300) < 0) {
			if (errno == EINTR)
				continue;
			break;
		}

		for (i = 0; i < nfd; i++) {
			struct input_event ev;
			int j;

			if (ino >= 0 && pf[i].fd == ino && (pf[i].revents & POLLIN)) {
				drain_inotify(ino);
				scan_menu_pads(pads, &npads);
			}
			for (j = 0; j < npads; j++) {
				if (pads[j].fd != pf[i].fd)
					continue;
				if (pf[i].revents & POLLIN) {
					while (read(pads[j].fd, &ev, sizeof ev) == (ssize_t)sizeof ev) {
						if (ev.type == EV_KEY && ev.code == BTN_MODE)
							pads[j].down = ev.value != 0;
					}
					menu = any_menu(pads, npads);
				}
				if (pf[i].revents & (POLLHUP | POLLERR | POLLNVAL)) {
					drop_menu_fd(pads, &npads, pf[i].fd);
					menu = any_menu(pads, npads);
				}
				break;
			}
			if (!(pf[i].revents & POLLIN))
				continue;
			if (pf[i].fd != hall_fd && pf[i].fd != pwr_fd && pf[i].fd != vol_fd)
				continue;
			while (read(pf[i].fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
				if (pf[i].fd == hall_fd && ev.type == EV_SW &&
				    ev.code == SW_LID && ev.value == 1)
					do_lid_sleep(hall_fd);
				if (pf[i].fd == pwr_fd && ev.type == EV_KEY &&
				    ev.code == KEY_POWER && ev.value == 1) {
					unsigned long long now = monotonic_ms();

					if (!power_ignore_until_ms || !now ||
					    now >= power_ignore_until_ms)
						do_mem_sleep();
				}
				if (pf[i].fd == vol_fd && ev.type == EV_KEY &&
				    (ev.value == 1 || ev.value == 2) &&
				    (ev.code == KEY_VOLUMEUP || ev.code == KEY_VOLUMEDOWN)) {
					if (!in_game)
						continue;
					if (menu)
						apply_bri(ev.code == KEY_VOLUMEUP);
					else
						apply_vol(ev.code == KEY_VOLUMEUP);
				}
			}
		}
	}

	if (vol_fd >= 0) {
		ioctl(vol_fd, EVIOCGRAB, 0);
		close(vol_fd);
	}
	if (hall_fd >= 0)
		close(hall_fd);
	if (pwr_fd >= 0)
		close(pwr_fd);
	while (npads > 0)
		drop_menu_fd(pads, &npads, pads[0].fd);
	if (ino >= 0)
		close(ino);
	return 0;
}
