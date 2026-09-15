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
#include <sys/ioctl.h>
#include <unistd.h>

#include "msettings.h"

#define VOL_NAME "gpio-keys-volume"
#define HALL_NAME "gpio-keys-hall"
#define PAD_NAME "retrogame_joypad"
#define VOLUME_MAX 20
#define BRIGHTNESS_MAX 10

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
		char path[64];
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

static void do_lid_sleep(void)
{
	if (menu_owns_keys())
		return;
	system("/usr/sbin/zlyme-radios pre >/dev/null 2>&1");
	if (access("/usr/share/nextui/bin/suspend", X_OK) == 0)
		system("/usr/share/nextui/bin/suspend");
	else if (access("/storage/.system/my355/bin/suspend", X_OK) == 0)
		system("/storage/.system/my355/bin/suspend");
	else
		system("echo mem > /sys/power/state");
	system("/usr/sbin/zlyme-radios resume >/dev/null 2>&1");
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

int main(void)
{
	struct pollfd pf[3];
	int vol_fd, hall_fd, pad_fd;
	int grabbed = 0;
	int menu = 0;
	int nfd;
	struct sigaction sa = {0};

	sa.sa_handler = on_term;
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);

	if (!getenv("USERDATA_PATH"))
		setenv("USERDATA_PATH", "/storage/.config/nextui/my355", 0);
	InitSettings();

	vol_fd = open_by_name(VOL_NAME);
	hall_fd = open_by_name(HALL_NAME);
	pad_fd = open_by_name(PAD_NAME);
	if (vol_fd < 0 && hall_fd < 0)
		return 1;

	nfd = 0;
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
	if (pad_fd >= 0) {
		pf[nfd].fd = pad_fd;
		pf[nfd].events = POLLIN;
		nfd++;
	}

	while (!quit) {
		int in_game = !menu_owns_keys();
		int i;

		if (vol_fd >= 0 && grabbed != in_game) {
			int g = in_game ? 1 : 0;
			ioctl(vol_fd, EVIOCGRAB, g);
			grabbed = in_game;
		}

		if (poll(pf, (nfds_t)nfd, 300) < 0) {
			if (errno == EINTR)
				continue;
			break;
		}

		for (i = 0; i < nfd; i++) {
			struct input_event ev;

			if (!(pf[i].revents & POLLIN))
				continue;
			while (read(pf[i].fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
				if (pf[i].fd == hall_fd && ev.type == EV_SW &&
				    ev.code == SW_LID && ev.value == 1)
					do_lid_sleep();
				if (pf[i].fd == pad_fd && ev.type == EV_KEY &&
				    ev.code == BTN_MODE)
					menu = ev.value != 0;
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
	if (pad_fd >= 0)
		close(pad_fd);
	return 0;
}
