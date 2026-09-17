// SPDX-License-Identifier: GPL-2.0
/*
 * Watch the headphone jack and set Playback Mux (HP / SPK).
 * simple-audio-card publishes hp-det as an evdev switch.
 */

#include <alsa/asoundlib.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/input.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

/* From simple-audio-card,name = "rk817_ext" plus the hp-det widget. */
#define JACK_NAME "rk817_ext Headphones"

/*
 * The codec is card 1, because the device tree also enables the HDMI link, so an
 * index here would be wrong as well as fragile. rk817ext is the card id.
 */
#define CARD_ID "hw:rk817ext"
#define CONTROL "Playback Mux"

/* dac_mux_text[] in the codec driver, in order. */
enum { MUX_HP = 0, MUX_SPK = 1 };

#define BITS_PER_LONG (8 * sizeof(unsigned long))
#define NLONGS(n) (((n) + BITS_PER_LONG - 1) / BITS_PER_LONG)
#define TEST_BIT(nr, addr) \
	(((addr)[(nr) / BITS_PER_LONG] >> ((nr) % BITS_PER_LONG)) & 1)

static void say(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
}

/*
 * Find the jack by name rather than by event number: the numbering depends on
 * probe order, so /dev/input/event3 is not a stable way to name anything.
 */
static int open_jack(void)
{
	struct dirent *ent;
	DIR *dir;
	int found = -1;

	dir = opendir("/dev/input");
	if (!dir) {
		say("zlyme-jackd: /dev/input: %s", strerror(errno));
		return -1;
	}

	while ((ent = readdir(dir))) {
		unsigned long sw[NLONGS(SW_CNT)];
		char path[PATH_MAX];
		char name[256] = "";
		int fd;

		if (strncmp(ent->d_name, "event", 5))
			continue;

		snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
		fd = open(path, O_RDONLY);
		if (fd < 0)
			continue;

		if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) < 0 ||
		    strcmp(name, JACK_NAME)) {
			close(fd);
			continue;
		}

		/*
		 * Right name, but confirm it really reports the switch before
		 * trusting it -- otherwise a rename upstream turns into a daemon
		 * that reads a descriptor which never produces an event.
		 */
		memset(sw, 0, sizeof(sw));
		if (ioctl(fd, EVIOCGBIT(EV_SW, sizeof(sw)), sw) < 0 ||
		    !TEST_BIT(SW_HEADPHONE_INSERT, sw)) {
			say("zlyme-jackd: \"%s\" has no SW_HEADPHONE_INSERT", name);
			close(fd);
			continue;
		}

		found = fd;
		break;
	}

	closedir(dir);
	return found;
}

static bool jack_inserted(int fd)
{
	unsigned long sw[NLONGS(SW_CNT)];

	memset(sw, 0, sizeof(sw));
	if (ioctl(fd, EVIOCGSW(sizeof(sw)), sw) < 0) {
		say("zlyme-jackd: EVIOCGSW: %s", strerror(errno));
		return false;
	}

	return TEST_BIT(SW_HEADPHONE_INSERT, sw);
}

static int set_route(snd_ctl_t *ctl, bool inserted)
{
	snd_ctl_elem_value_t *val;
	snd_ctl_elem_id_t *id;
	int err;

	snd_ctl_elem_id_alloca(&id);
	snd_ctl_elem_value_alloca(&val);

	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, CONTROL);
	snd_ctl_elem_value_set_id(val, id);

	/*
	 * A DAPM mux is enumerated, so this writes an index and not a volume.
	 * Both channels get the same value: the mux routes the pair together.
	 */
	snd_ctl_elem_value_set_enumerated(val, 0, inserted ? MUX_HP : MUX_SPK);
	snd_ctl_elem_value_set_enumerated(val, 1, inserted ? MUX_HP : MUX_SPK);

	err = snd_ctl_elem_write(ctl, val);
	if (err < 0) {
		say("zlyme-jackd: writing %s: %s", CONTROL, snd_strerror(err));
		return err;
	}

	say("zlyme-jackd: output -> %s", inserted ? "headphones" : "speaker");
	return 0;
}

int main(void)
{
	snd_ctl_t *ctl = NULL;
	int jack, err;

	/*
	 * Exit 0, not 1, when the hardware is not there.
	 *
	 * Nothing here can start working without a reboot, so failing would put
	 * the daemon into a restart loop against a condition that cannot change --
	 * which is how a previous image on this device was eaten by a service doing
	 * exactly that. Saying so once and leaving is the correct behaviour.
	 */
	jack = open_jack();
	if (jack < 0) {
		say("zlyme-jackd: no \"%s\" input device -- nothing to watch", JACK_NAME);
		return 0;
	}

	err = snd_ctl_open(&ctl, CARD_ID, 0);
	if (err < 0) {
		say("zlyme-jackd: %s: %s", CARD_ID, snd_strerror(err));
		close(jack);
		return 0;
	}

	/*
	 * Prime the route before reporting ready, so whatever starts next does not
	 * open a device that is pointed at the wrong output. Headphones already in
	 * the socket at boot is the common case, and it is the one that looks like
	 * broken audio rather than a missing daemon.
	 */
	if (set_route(ctl, jack_inserted(jack)) < 0) {
		snd_ctl_close(ctl);
		close(jack);
		return 0;
	}

	for (;;) {
		struct input_event ev;
		ssize_t n = read(jack, &ev, sizeof(ev));

		if (n < 0) {
			if (errno == EINTR)
				continue;
			say("zlyme-jackd: read: %s", strerror(errno));
			break;
		}

		/* A short read means the descriptor is not what we think it is. */
		if (n != (ssize_t)sizeof(ev))
			break;

		if (ev.type == EV_SW && ev.code == SW_HEADPHONE_INSERT)
			set_route(ctl, ev.value != 0);
	}

	snd_ctl_close(ctl);
	close(jack);
	return 0;
}
