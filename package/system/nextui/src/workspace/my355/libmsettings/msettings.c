/*
 * libmsettings for Zlyme.
 *
 * Stock my355 talks to BSP mixer names (Playback Path, SPK) and a GPIO
 * jack. This device has FlipVolume on the rk817ext card and flip-jackd
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
#include <linux/input.h>

#include "msettings.h"

#define SETTINGS_VERSION 2
typedef struct Settings {
	int version;
	int brightness;
	int headphones;
	int speaker;
	int unused[2];
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
#define SHM_KEY "/SharedSettings"
static char SettingsPath[256];
static int shm_fd = -1;
static int is_host = 0;
static const int shm_size = sizeof(Settings);

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

static int HDMI_enabled(void)
{
	char value[64];

	getFile(HDMI_STATE_PATH, value, sizeof(value));
	return strncmp(value, "connected", 9) == 0;
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

static void SaveSettings(void)
{
	int fd = open(SettingsPath, O_CREAT | O_WRONLY, 0644);

	if (fd >= 0) {
		if (write(fd, settings, shm_size) != shm_size)
			/* ignore */;
		close(fd);
		sync();
	}
}

void InitSettings(void)
{
	char *home = getenv("USERDATA_PATH");

	snprintf(SettingsPath, sizeof(SettingsPath), "%s/msettings.bin",
		 home && home[0] ? home : "/tmp");

	shm_fd = shm_open(SHM_KEY, O_RDWR | O_CREAT | O_EXCL, 0644);
	if (shm_fd == -1 && errno == EEXIST) {
		shm_fd = shm_open(SHM_KEY, O_RDWR, 0644);
		settings = mmap(NULL, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
	} else {
		is_host = 1;
		if (ftruncate(shm_fd, shm_size) < 0)
			/* ignore */;
		settings = mmap(NULL, shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);

		int fd = open(SettingsPath, O_RDONLY);
		if (fd >= 0) {
			if (read(fd, settings, shm_size) != shm_size)
				memcpy(settings, &DefaultSettings, shm_size);
			close(fd);
		} else {
			memcpy(settings, &DefaultSettings, shm_size);
		}
	}

	settings->jack = jack_from_evdev();
	settings->hdmi = HDMI_enabled();
	SetVolume(GetVolume());
	SetBrightness(GetBrightness());
}

void QuitSettings(void)
{
	munmap(settings, shm_size);
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
	/* FlipVolume is the one softvol on rk817ext. flip-jackd owns the mux. */
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
	return settings->hdmi;
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
int GetContrast(void) { return 0; }
int GetSaturation(void) { return 0; }
int GetExposure(void) { return 0; }
void SetRawColortemp(int value) { (void)value; }
void SetRawContrast(int value) { (void)value; }
void SetRawSaturation(int value) { (void)value; }
void SetRawExposure(int value) { (void)value; }
void SetColortemp(int value) { (void)value; }
void SetContrast(int value) { (void)value; }
void SetSaturation(int value) { (void)value; }
void SetExposure(int value) { (void)value; }

int GetAudioSink(void)
{
	return settings ? settings->audiosink : 0;
}

void SetAudioSink(int value)
{
	if (settings)
		settings->audiosink = value;
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
