/*
 * libmsettings for Zlyme.
 *
 * Stock my355 talks to BSP mixer names (Playback Path, SPK) and a GPIO
 * jack. This device has FlipVolume on the rk817ext card and zlyme-jackd
 * already owns Playback Mux. One volume for speaker and headphones.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <errno.h>
#include <sys/stat.h>
#include <string.h>
#include <sys/ioctl.h>
#include <dirent.h>
#include <stdint.h>
#include <linux/input.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

#include "msettings.h"

#define SETTINGS_VERSION 2
typedef struct Settings {
	int version;
	int brightness;
	int headphones;
	int speaker;
	int contrast; /* NextUI -4..5, 0 = identity */
	int saturation; /* NextUI -5..5, 0 = identity */
	int jack;
	int hdmi;
	int audiosink;
} Settings;

static Settings DefaultSettings = {
	.version = SETTINGS_VERSION,
	.brightness = 5,
	.headphones = 8,
	.speaker = 8,
	.jack = 0,
	.hdmi = 0,
	.audiosink = 0,
};

static Settings *settings;
static Settings FallbackSettings;
#define SHM_KEY "/SharedSettings"
static char SettingsPath[256];
static int shm_fd = -1;
static int is_host = 0;
static const int shm_size = sizeof(Settings);

static void settings_fallback(void)
{
	FallbackSettings = DefaultSettings;
	settings = &FallbackSettings;
	if (shm_fd >= 0) {
		close(shm_fd);
		shm_fd = -1;
	}
	if (is_host)
		shm_unlink(SHM_KEY);
	is_host = 0;
}

#define BRIGHTNESS_PATH "/sys/class/backlight/backlight/brightness"
#define HDMI_STATE_PATH "/sys/class/drm/card0-HDMI-A-1/status"

static int getInt(char *path)
{
	int i = 0;
	FILE *file = fopen(path, "r");

	if (file) {
		if (fscanf(file, "%i", &i) != 1)
			i = 0;
		fclose(file);
	}
	return i;
}

static void getFile(char *path, char *buffer, size_t buffer_size)
{
	FILE *file = fopen(path, "r");

	buffer[0] = '\0';
	if (!file)
		return;
	size_t n = fread(buffer, 1, buffer_size - 1, file);
	fclose(file);
	buffer[n] = '\0';
}

static void putFile(char *path, char *contents)
{
	FILE *file = fopen(path, "w");

	if (file) {
		fputs(contents, file);
		fclose(file);
	}
}

static void putInt(char *path, int value)
{
	char buffer[16];

	snprintf(buffer, sizeof(buffer), "%d", value);
	putFile(path, buffer);
}

static int clamp_int(int v, int lo, int hi)
{
	if (v < lo)
		return lo;
	if (v > hi)
		return hi;
	return v;
}

/* Contrast/saturation mapping kept out of apply_bcsh: those DRM TV
 * properties black this DSI panel. Identity is 50. */

static int existing_drm_fd(void)
{
	DIR *d = opendir("/proc/self/fd");
	struct dirent *e;
	int best = -1;

	if (!d)
		return -1;
	while ((e = readdir(d))) {
		char path[64], link[128];
		ssize_t n;
		int fd;

		if (e->d_name[0] == '.')
			continue;
		fd = atoi(e->d_name);
		snprintf(path, sizeof(path), "/proc/self/fd/%s", e->d_name);
		n = readlink(path, link, sizeof(link) - 1);
		if (n < 0)
			continue;
		link[n] = '\0';
		if (!strstr(link, "dri/card"))
			continue;
		if (drmIsMaster(fd)) {
			closedir(d);
			return fd;
		}
		best = fd;
	}
	closedir(d);
	return best;
}

static int open_drm_fd(int *owned)
{
	int fd = existing_drm_fd();
	static const char *cards[] = { "/dev/dri/card0", "/dev/dri/card1", NULL };
	int i;

	*owned = 0;
	if (fd >= 0)
		return fd;
	for (i = 0; cards[i]; i++) {
		fd = open(cards[i], O_RDWR | O_CLOEXEC);
		if (fd >= 0) {
			*owned = 1;
			return fd;
		}
	}
	return -1;
}

static void set_conn_tv_prop(int fd, uint32_t conn_id, drmModeObjectProperties *props,
			     const char *name, uint64_t value)
{
	uint32_t i;

	for (i = 0; i < props->count_props; i++) {
		drmModePropertyPtr p = drmModeGetProperty(fd, props->props[i]);

		if (!p)
			continue;
		if (strcmp(p->name, name) == 0)
			drmModeObjectSetProperty(fd, conn_id, DRM_MODE_OBJECT_CONNECTOR,
						 p->prop_id, value);
		drmModeFreeProperty(p);
	}
}

static void apply_bcsh(void)
{
	int owned = 0;
	int fd = open_drm_fd(&owned);
	drmModeRes *res;
	int ci;
	/* Contrast/saturation on this DSI panel go black (identity is 50).
	 * Keep brightness and hue at identity. */
	int drm_c = 50;
	int drm_s = 50;

	if (fd < 0)
		return;
	res = drmModeGetResources(fd);
	if (!res) {
		if (owned)
			close(fd);
		return;
	}
	for (ci = 0; ci < res->count_connectors; ci++) {
		drmModeConnector *conn = drmModeGetConnectorCurrent(fd, res->connectors[ci]);
		drmModeObjectProperties *props;

		if (!conn)
			continue;
		props = drmModeObjectGetProperties(fd, conn->connector_id, DRM_MODE_OBJECT_CONNECTOR);
		if (props) {
			set_conn_tv_prop(fd, conn->connector_id, props, "brightness", 50);
			set_conn_tv_prop(fd, conn->connector_id, props, "contrast", (uint64_t)drm_c);
			set_conn_tv_prop(fd, conn->connector_id, props, "saturation", (uint64_t)drm_s);
			set_conn_tv_prop(fd, conn->connector_id, props, "hue", 50);
			drmModeFreeObjectProperties(props);
		}
		drmModeFreeConnector(conn);
	}
	drmModeFreeResources(res);
	if (owned)
		close(fd);
}

static int HDMI_enabled(void)
{
	static const char *paths[] = {
		"/sys/class/drm/card0-HDMI-A-1/status",
		"/sys/class/drm/card1-HDMI-A-1/status",
		NULL
	};
	char value[64];
	int i;

	for (i = 0; paths[i]; i++) {
		getFile((char *)paths[i], value, sizeof(value));
		if (strncmp(value, "connected", 9) == 0)
			return 1;
	}
	return 0;
}

static int jack_from_evdev(void)
{
	char name[256];
	char path[64];
	unsigned char sw[(SW_MAX + 7) / 8];
	int fd, i;

	for (i = 0; i < 16; i++) {
		snprintf(path, sizeof(path), "/sys/class/input/event%d/device/name", i);
		getFile(path, name, sizeof(name));
		if (!strstr(name, "Headphones"))
			continue;
		snprintf(path, sizeof(path), "/dev/input/event%d", i);
		fd = open(path, O_RDONLY | O_CLOEXEC);
		if (fd < 0)
			return 0;
		if (ioctl(fd, EVIOCGSW(sizeof(sw)), sw) < 0) {
			close(fd);
			return 0;
		}
		close(fd);
		return !!(sw[SW_HEADPHONE_INSERT / 8] & (1 << (SW_HEADPHONE_INSERT % 8)));
	}
	return 0;
}

static int settings_applying;

static void SaveSettings(void)
{
	int fd;

	if (settings_applying)
		return;

	fd = open(SettingsPath, O_CREAT | O_WRONLY, 0644);

	if (fd >= 0) {
		if (write(fd, settings, shm_size) != shm_size)
			/* ignore */;
		close(fd);
	}
}

void InitSettings(void)
{
	char *home = getenv("USERDATA_PATH");

	snprintf(SettingsPath, sizeof(SettingsPath), "%s/msettings.bin",
		 home && home[0] ? home : "/tmp");

	shm_fd = shm_open(SHM_KEY, O_RDWR | O_CREAT | O_EXCL, 0644);
	if (shm_fd == -1 && errno == EEXIST)
		shm_fd = shm_open(SHM_KEY, O_RDWR, 0644);
	else if (shm_fd >= 0)
		is_host = 1;

	if (shm_fd < 0) {
		settings_fallback();
	} else {
		if (is_host && ftruncate(shm_fd, shm_size) < 0)
			/* ignore */;
		settings = mmap(NULL, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
		if (settings == MAP_FAILED || settings == NULL) {
			settings_fallback();
		} else if (is_host) {
			int fd = open(SettingsPath, O_RDONLY);
			if (fd >= 0) {
				if (read(fd, settings, shm_size) != shm_size)
					memcpy(settings, &DefaultSettings, shm_size);
				close(fd);
			} else {
				memcpy(settings, &DefaultSettings, shm_size);
			}
		}
	}

	settings->jack = jack_from_evdev();
	settings->hdmi = HDMI_enabled();
	if (settings->contrast != 0)
		settings->contrast = 0;
	if (settings->saturation != 0)
		settings->saturation = 0;
	settings_applying = 1;
	SetVolume(GetVolume());
	SetBrightness(GetBrightness());
	settings_applying = 0;
	/* Identity TV props. Opening DRM here raced SDL KMS. */
}

void QuitSettings(void)
{
	if (settings && settings != &FallbackSettings)
		munmap(settings, shm_size);
	settings = NULL;
	if (shm_fd >= 0) {
		close(shm_fd);
		shm_fd = -1;
	}
	if (is_host)
		shm_unlink(SHM_KEY);
}

int GetBrightness(void)
{
	return settings->brightness;
}

void SetRawBrightness(int val)
{
	if (settings->hdmi)
		return;
	putInt(BRIGHTNESS_PATH, val);
}

void SetBrightness(int value)
{
	static const int raw[11] = { 8, 16, 32, 48, 64, 96, 128, 160, 192, 224, 255 };

	if (value < 0)
		value = 0;
	if (value > 10)
		value = 10;
	settings->brightness = value;
	SetRawBrightness(raw[value]);
	SaveSettings();
}

int GetVolume(void)
{
	return settings->jack ? settings->headphones : settings->speaker;
}

void SetRawVolume(int val)
{
	char cmd[128];

	if (val < 0)
		val = 0;
	if (val > 100)
		val = 100;
	/* FlipVolume is the one softvol on rk817ext. zlyme-jackd owns the mux. */
	snprintf(cmd, sizeof(cmd), "amixer -q sset FlipVolume %i%%", val);
	if (system(cmd) != 0)
		/* control appears the first time a PCM opens; ignore */;
}

void SetVolume(int value)
{
	if (value < 0)
		value = 0;
	if (value > 20)
		value = 20;
	if (settings->jack)
		settings->headphones = value;
	else
		settings->speaker = value;
	SetRawVolume(value * 5);
	SaveSettings();
}

int GetJack(void)
{
	return settings->jack;
}

void SetJack(int value)
{
	settings->jack = value;
	SetVolume(GetVolume());
}

int GetHDMI(void)
{
	int on = HDMI_enabled();

	if (settings)
		settings->hdmi = on;
	return on;
}

void SetHDMI(int value)
{
	settings->hdmi = value;
	if (value)
		SetRawVolume(100);
	else
		SetVolume(GetVolume());
}

int GetMute(void)
{
	return 0;
}

void SetMute(int value)
{
	(void)value;
}

int InitializedSettings(void)
{
	return settings != NULL;
}

int GetDisplayCalEnabled(void) { return 0; }
int GetDisplayCalRedGain(void) { return 100; }
int GetDisplayCalGreenGain(void) { return 100; }
int GetDisplayCalBlueGain(void) { return 100; }
void SetDisplayCalEnabled(int value) { (void)value; }
void SetDisplayCalRedGain(int value) { (void)value; }
void SetDisplayCalGreenGain(int value) { (void)value; }
void SetDisplayCalBlueGain(int value) { (void)value; }

int GetColortemp(void) { return 0; }
int GetContrast(void)
{
	return settings ? clamp_int(settings->contrast, -4, 5) : 0;
}
int GetSaturation(void)
{
	return settings ? clamp_int(settings->saturation, -5, 5) : 0;
}
int GetExposure(void) { return 0; }
void SetRawColortemp(int value) { (void)value; }
void SetRawContrast(int value)
{
	SetContrast((clamp_int(value, 0, 100) - 50) / 5);
}
void SetRawSaturation(int value)
{
	SetSaturation((clamp_int(value, 0, 100) - 50) / 10);
}
void SetRawExposure(int value) { (void)value; }
void SetColortemp(int value) { (void)value; }
void SetContrast(int value)
{
	if (!settings)
		return;
	settings->contrast = clamp_int(value, -4, 5);
	apply_bcsh();
	SaveSettings();
}
void SetSaturation(int value)
{
	if (!settings)
		return;
	settings->saturation = clamp_int(value, -5, 5);
	apply_bcsh();
	SaveSettings();
}
void SetExposure(int value) { (void)value; }

int GetAudioSink(void)
{
	return settings ? settings->audiosink : 0;
}

void SetAudioSink(int value)
{
	const char *sink = "codec";

	if (value == AUDIO_SINK_BLUETOOTH)
		sink = "bt";
	else if (value == AUDIO_SINK_HDMI)
		sink = "hdmi";
	else
		value = AUDIO_SINK_DEFAULT;
	if (settings)
		settings->audiosink = value;
	char cmd[80];

	snprintf(cmd, sizeof(cmd), "zlyme-audio set %s >/dev/null 2>&1", sink);
	if (system(cmd) != 0)
		/* sink file may be missing before the card is mounted */;
	SetVolume(GetVolume());
}

int GetMutedBrightness(void) { return 0; }
int GetMutedColortemp(void) { return 0; }
int GetMutedContrast(void) { return 0; }
int GetMutedSaturation(void) { return 0; }
int GetMutedExposure(void) { return 0; }
int GetMutedVolume(void) { return 0; }
int GetMuteDisablesDpad(void) { return 0; }
int GetMuteEmulatesJoystick(void) { return 0; }
int GetMuteTurboA(void) { return 0; }
int GetMuteTurboB(void) { return 0; }
int GetMuteTurboX(void) { return 0; }
int GetMuteTurboY(void) { return 0; }
int GetMuteTurboL1(void) { return 0; }
int GetMuteTurboL2(void) { return 0; }
int GetMuteTurboR1(void) { return 0; }
int GetMuteTurboR2(void) { return 0; }
void SetMutedBrightness(int v) { (void)v; }
void SetMutedColortemp(int v) { (void)v; }
void SetMutedContrast(int v) { (void)v; }
void SetMutedSaturation(int v) { (void)v; }
void SetMutedExposure(int v) { (void)v; }
void SetMutedVolume(int v) { (void)v; }
void SetMuteDisablesDpad(int v) { (void)v; }
void SetMuteEmulatesJoystick(int v) { (void)v; }
void SetMuteTurboA(int v) { (void)v; }
void SetMuteTurboB(int v) { (void)v; }
void SetMuteTurboX(int v) { (void)v; }
void SetMuteTurboY(int v) { (void)v; }
void SetMuteTurboL1(int v) { (void)v; }
void SetMuteTurboL2(int v) { (void)v; }
void SetMuteTurboR1(int v) { (void)v; }
void SetMuteTurboR2(int v) { (void)v; }
