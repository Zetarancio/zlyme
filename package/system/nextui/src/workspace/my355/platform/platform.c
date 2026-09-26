// my355
#include <stdio.h>
#include <stdlib.h>
#include <linux/fb.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include <assert.h>

#include <msettings.h>

#include "defines.h"
#include "platform.h"
#include "api.h"
#include "utils.h"

#include "scaler.h"
#include <time.h>
#include <pthread.h>

#include <linux/input.h>
#include <dirent.h>
#include <string.h>
#include <stdint.h>

///////////////////////////////

int on_hdmi = 0;

#define HDMI_STATE_PATH "/sys/class/drm/card0-HDMI-A-1/status"

static int HDMI_enabled(void) {
	char value[64];
	getFile(HDMI_STATE_PATH, value, 64);
	return exactMatch(value, "connected\n");
}

/* Same hall node as ROCKNIX: SW_LID, GPIO_ACTIVE_LOW, wake on open. */
static int lid_fd = -1;

static int lid_open_from_sw(const unsigned char *sw, size_t n)
{
	unsigned bit = SW_LID;
	if (bit / 8 >= n)
		return 1;
	/* Linux: 1 = closed. */
	return !(sw[bit / 8] & (1u << (bit % 8)));
}

void PLAT_initLid(void)
{
	DIR *dir;
	struct dirent *de;
	unsigned char sw[(SW_MAX / 8) + 1];

	lid.has_lid = 0;
	lid.is_open = 1;
	lid_fd = -1;
	dir = opendir("/dev/input");
	if (!dir)
		return;
	while ((de = readdir(dir))) {
		char path[64];
		int fd;
		if (strncmp(de->d_name, "event", 5) != 0)
			continue;
		snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);
		fd = open(path, O_RDONLY | O_NONBLOCK);
		if (fd < 0)
			continue;
		memset(sw, 0, sizeof(sw));
		if (ioctl(fd, EVIOCGSW(sizeof(sw)), sw) < 0) {
			close(fd);
			continue;
		}
		/* EVIOCGSW succeeds on any evdev; require a lid bit changing
		 * capability via EVIOCGBIT. */
		{
			unsigned long evbit[EV_MAX / (8 * sizeof(long)) + 1];
			unsigned long swbit[SW_MAX / (8 * sizeof(long)) + 1];
			memset(evbit, 0, sizeof(evbit));
			memset(swbit, 0, sizeof(swbit));
			if (ioctl(fd, EVIOCGBIT(0, sizeof(evbit)), evbit) < 0 ||
			    !(evbit[EV_SW / (8 * sizeof(long))] & (1UL << (EV_SW % (8 * sizeof(long)))))) {
				close(fd);
				continue;
			}
			if (ioctl(fd, EVIOCGBIT(EV_SW, sizeof(swbit)), swbit) < 0 ||
			    !(swbit[SW_LID / (8 * sizeof(long))] & (1UL << (SW_LID % (8 * sizeof(long)))))) {
				close(fd);
				continue;
			}
		}
		lid_fd = fd;
		lid.has_lid = 1;
		lid.is_open = lid_open_from_sw(sw, sizeof(sw));
		break;
	}
	closedir(dir);
}

int PLAT_lidChanged(int *state)
{
	struct input_event ev;
	int changed = 0;
	if (lid_fd < 0)
		return 0;
	while (read(lid_fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
		if (ev.type == EV_SW && ev.code == SW_LID) {
			lid.is_open = !ev.value;
			changed = 1;
		}
	}
	if (state)
		*state = lid.is_open;
	return changed;
}

int PLAT_shouldWake(void)
{
	int lid_open = 1;
	SDL_Event event;

	if (lid.has_lid && PLAT_lidChanged(&lid_open) && lid_open)
		return 1;
	if (lid.has_lid && !lid.is_open)
		return 0;

	while (SDL_PollEvent(&event)) {
		if (event.type == SDL_KEYUP || event.type == SDL_JOYBUTTONUP)
			return 1;
	}
	return 0;
}

///////////////////////////////

#define ZLYME_PHYS_PAD "Miyoo Flip Gamepad"
#define ZLYME_VIRT_PAD "Microsoft X-Box 360 pad"

static SDL_Joystick **joysticks = NULL;
static int num_joysticks = 0;
static SDL_GameController **controllers = NULL;
static int num_controllers = 0;

static int name_is(SDL_Joystick *joy, const char *want)
{
	const char *name = joy ? SDL_JoystickName(joy) : NULL;
	return name && strcmp(name, want) == 0;
}

static int virtual_open(void)
{
	int i;
	for (i = 0; i < num_controllers; i++) {
		SDL_Joystick *joy = SDL_GameControllerGetJoystick(controllers[i]);
		if (name_is(joy, ZLYME_VIRT_PAD))
			return 1;
	}
	for (i = 0; i < num_joysticks; i++) {
		if (name_is(joysticks[i], ZLYME_VIRT_PAD))
			return 1;
	}
	return 0;
}

static void close_named(const char *want)
{
	int i;
	for (i = 0; i < num_controllers; ) {
		SDL_Joystick *joy = SDL_GameControllerGetJoystick(controllers[i]);
		if (!name_is(joy, want)) {
			i++;
			continue;
		}
		SDL_GameControllerClose(controllers[i]);
		for (int j = i; j < num_controllers - 1; j++)
			controllers[j] = controllers[j + 1];
		num_controllers--;
	}
	for (i = 0; i < num_joysticks; ) {
		if (!name_is(joysticks[i], want)) {
			i++;
			continue;
		}
		SDL_JoystickClose(joysticks[i]);
		for (int j = i; j < num_joysticks - 1; j++)
			joysticks[j] = joysticks[j + 1];
		num_joysticks--;
	}
	if (num_controllers == 0) {
		free(controllers);
		controllers = NULL;
	}
	if (num_joysticks == 0) {
		free(joysticks);
		joysticks = NULL;
	}
}

static int already_open(SDL_JoystickID iid)
{
	int i;
	for (i = 0; i < num_controllers; i++) {
		SDL_Joystick *joy = SDL_GameControllerGetJoystick(controllers[i]);
		if (joy && SDL_JoystickInstanceID(joy) == iid)
			return 1;
	}
	for (i = 0; i < num_joysticks; i++) {
		if (joysticks[i] && SDL_JoystickInstanceID(joysticks[i]) == iid)
			return 1;
	}
	return 0;
}

static void remember_joystick(SDL_Joystick *joy)
{
	joysticks = realloc(joysticks, sizeof(SDL_Joystick *) * (num_joysticks + 1));
	joysticks[num_joysticks++] = joy;
}

static void remember_controller(SDL_GameController *ctrl)
{
	controllers = realloc(controllers, sizeof(SDL_GameController *) * (num_controllers + 1));
	controllers[num_controllers++] = ctrl;
}

static void open_index(int device_index)
{
	const char *name = SDL_JoystickNameForIndex(device_index);
	SDL_Joystick *probe;
	SDL_JoystickID iid;

	if (!name)
		return;
	if (virtual_open() && strcmp(name, ZLYME_PHYS_PAD) == 0)
		return;
	probe = SDL_JoystickOpen(device_index);
	if (!probe)
		return;
	iid = SDL_JoystickInstanceID(probe);
	SDL_JoystickClose(probe);
	if (already_open(iid))
		return;
	if (SDL_IsGameController(device_index)) {
		SDL_GameController *ctrl = SDL_GameControllerOpen(device_index);
		if (!ctrl) {
			LOG_error("GameController open failed: %s\n", SDL_GetError());
			return;
		}
		remember_controller(ctrl);
		LOG_info("Controller added: %s\n", SDL_GameControllerName(ctrl));
		if (strcmp(name, ZLYME_VIRT_PAD) == 0)
			close_named(ZLYME_PHYS_PAD);
		return;
	}
	probe = SDL_JoystickOpen(device_index);
	if (!probe)
		return;
	remember_joystick(probe);
	LOG_info("Joystick added: %s\n", SDL_JoystickName(probe));
	if (strcmp(name, ZLYME_VIRT_PAD) == 0)
		close_named(ZLYME_PHYS_PAD);
}

static void reopen_physical_if_needed(void)
{
	int i, n;
	if (virtual_open())
		return;
	n = SDL_NumJoysticks();
	for (i = 0; i < n; i++) {
		const char *name = SDL_JoystickNameForIndex(i);
		if (name && strcmp(name, ZLYME_PHYS_PAD) == 0)
			open_index(i);
	}
}

int PLAT_suppressRawJoy(SDL_JoystickID id)
{
	int i;
	for (i = 0; i < num_controllers; i++) {
		SDL_Joystick *joy = SDL_GameControllerGetJoystick(controllers[i]);
		if (joy && SDL_JoystickInstanceID(joy) == id)
			return 1;
	}
	return 0;
}

void PLAT_initInput(void) {
	const char *map = getenv("SDL_GAMECONTROLLERCONFIG_FILE");
	if (!map || !map[0])
		map = "/usr/lib/gamecontrollerdb.txt";
	if (SDL_InitSubSystem(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) < 0)
		LOG_error("Failed initializing joysticks: %s\n", SDL_GetError());
	if (SDL_GameControllerAddMappingsFromFile(map) < 0)
		LOG_info("Controller mappings not loaded from %s: %s\n", map, SDL_GetError());
	SDL_JoystickEventState(SDL_ENABLE);
	SDL_GameControllerEventState(SDL_ENABLE);
	/* Open on device-added only. Opening here and on ADDED duplicated
	 * the gamepad in the log. */
}

void PLAT_quitInput(void) {
	int i;
	for (i = 0; i < num_controllers; i++)
		SDL_GameControllerClose(controllers[i]);
	free(controllers);
	controllers = NULL;
	num_controllers = 0;
	for (i = 0; i < num_joysticks; i++) {
		if (SDL_JoystickGetAttached(joysticks[i]))
			SDL_JoystickClose(joysticks[i]);
	}
	free(joysticks);
	joysticks = NULL;
	num_joysticks = 0;
	SDL_QuitSubSystem(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER);
}

void PLAT_updateInput(const SDL_Event *event) {
	switch (event->type) {
	case SDL_JOYDEVICEADDED:
	case SDL_CONTROLLERDEVICEADDED:
		open_index(event->jdevice.which);
		break;
	case SDL_JOYDEVICEREMOVED:
	case SDL_CONTROLLERDEVICEREMOVED: {
		SDL_JoystickID removed_id = event->jdevice.which;
		int i;
		for (i = 0; i < num_controllers; i++) {
			SDL_Joystick *joy = SDL_GameControllerGetJoystick(controllers[i]);
			if (joy && SDL_JoystickInstanceID(joy) == removed_id) {
				LOG_info("Controller removed: %s\n", SDL_GameControllerName(controllers[i]));
				SDL_GameControllerClose(controllers[i]);
				for (int j = i; j < num_controllers - 1; j++)
					controllers[j] = controllers[j + 1];
				num_controllers--;
				if (num_controllers == 0) {
					free(controllers);
					controllers = NULL;
				}
				reopen_physical_if_needed();
				return;
			}
		}
		for (i = 0; i < num_joysticks; i++) {
			if (joysticks[i] && SDL_JoystickInstanceID(joysticks[i]) == removed_id) {
				LOG_info("Joystick removed: %s\n", SDL_JoystickName(joysticks[i]));
				SDL_JoystickClose(joysticks[i]);
				for (int j = i; j < num_joysticks - 1; j++)
					joysticks[j] = joysticks[j + 1];
				num_joysticks--;
				if (num_joysticks == 0) {
					free(joysticks);
					joysticks = NULL;
				}
				reopen_physical_if_needed();
				return;
			}
		}
		break;
	}
	default:
		break;
	}
}

void PLAT_getBatteryStatus(int* is_charging, int* charge) {
	PLAT_getBatteryStatusFine(is_charging, charge);

	// worry less about battery and more about the game you're playing
	     if (*charge>80) *charge = 100;
	else if (*charge>60) *charge =  80;
	else if (*charge>40) *charge =  60;
	else if (*charge>20) *charge =  40;
	else if (*charge>10) *charge =  20;
	else           		 *charge =  10;
}

void PLAT_getCPUTemp() {
	perf.cpu_temp = getInt("/sys/devices/virtual/thermal/thermal_zone0/temp")/1000;
}

void PLAT_getCPUSpeed()
{
	perf.cpu_speed = getInt("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq")/1000;
}

void PLAT_getGPUTemp() {
	perf.gpu_temp = getInt("/sys/devices/virtual/thermal/thermal_zone1/temp")/1000;
}

void PLAT_getGPUSpeed() {
	// TODO
	perf.gpu_speed = 42; // MHz
}

static struct WIFI_connection connection = {
	.valid = false,
	.freq = -1,
	.link_speed = -1,
	.noise = -1,
	.rssi = -1,
	.ip = {0},
	.ssid = {0},
};

static inline void connection_reset(struct WIFI_connection *connection_info)
{
	connection_info->valid = false;
	connection_info->freq = -1;
	connection_info->link_speed = -1;
	connection_info->noise = -1;
	connection_info->rssi = -1;
	*connection_info->ip = '\0';
	*connection_info->ssid = '\0';
}

static bool bluetoothConnected = false;

void PLAT_getNetworkStatus(int* is_online)
{
	if(WIFI_enabled())
		WIFI_connectionInfo(&connection);
	else
		connection_reset(&connection);
	
	if(is_online)
		*is_online = (connection.valid && connection.ssid[0] != '\0');
	
	if(BT_enabled()) {
		bluetoothConnected = PLAT_bluetoothConnected();
	}
	else
		bluetoothConnected = false;
}

static void psy_read(const char *dir, const char *name, char *buf, size_t n)
{
	char path[192];

	buf[0] = '\0';
	snprintf(path, sizeof path, "%s/%s", dir, name);
	getFile(path, buf, n);
}

void PLAT_getBatteryStatusFine(int* is_charging, int* charge)
{
	int charging = 0;
	int cap = -1;
	DIR *dir = opendir("/sys/class/power_supply");

	/* RK817 often reports time_to_full_now as 0/-1 even while charging,
	 * and the charger class may be named rk817-charger rather than charger. */
	if (dir) {
		struct dirent *de;
		while ((de = readdir(dir))) {
			char path[192], type[32], status[32], cap_path[192];
			if (de->d_name[0] == '.')
				continue;
			snprintf(path, sizeof path, "/sys/class/power_supply/%s", de->d_name);
			psy_read(path, "type", type, sizeof type);
			psy_read(path, "status", status, sizeof status);
			if (prefixMatch("Battery", type) || prefixMatch("battery", de->d_name)) {
				snprintf(cap_path, sizeof cap_path, "%s/capacity", path);
				if (cap < 0)
					cap = getInt(cap_path);
				if (prefixMatch("Charging", status) || prefixMatch("Full", status))
					charging = 1;
				continue;
			}
			snprintf(cap_path, sizeof cap_path, "%s/online", path);
			if (getInt(cap_path) == 1)
				charging = 1;
		}
		closedir(dir);
	}

	if (is_charging)
		*is_charging = charging;
	if (charge) {
		if (cap < 0)
			cap = getInt("/sys/class/power_supply/battery/capacity");
		*charge = cap < 0 ? 0 : cap;
	}
}

#define BLANK_PATH "/sys/class/backlight/backlight/bl_power"
void PLAT_enableBacklight(int enable) {
	if (enable) {
		putInt(BLANK_PATH, FB_BLANK_UNBLANK); // wake
		SetBrightness(GetBrightness());
	}
	else {
		putInt(BLANK_PATH, FB_BLANK_POWERDOWN); // sleep
		SetRawBrightness(0);
	}
}

void PLAT_powerOff(int reboot) {
	if (CFG_getHaptics()) {
		VIB_singlePulse(VIB_bootStrength, VIB_bootDuration_ms);
	}
	system("rm -f /tmp/nextui_exec && sync");
	sleep(2);

	SetRawVolume(MUTE_VOLUME_RAW);
	system("zlyme-led poweroff >/dev/null 2>&1");
	PLAT_enableBacklight(0);
	SND_quit();
	VIB_quit();
	PWR_quit();
	GFX_quit();

	system("cat /dev/zero > /dev/fb0 2>/dev/null");
	if(reboot > 0)
		touch("/tmp/reboot");
	else
		touch("/tmp/poweroff");
	sync();
	exit(0);
}

int PLAT_supportsDeepSleep(void) { return 1; }

///////////////////////////////


double get_time_sec() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9; // Convert to seconds
}
double get_process_cpu_time_sec() {
	// this gives cpu time in nanoseconds needed to accurately calculate cpu usage in very short time frames.
	// unfortunately about 20ms between meassures seems the lowest i can go to get accurate results
	// maybe in the future i will find and even more granual way to get cpu time, but might just be a limit of C or Linux alltogether
    struct timespec ts;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9; // Convert to seconds
}

static pthread_mutex_t currentcpuinfo;
// a roling average for the display values of about 2 frames, otherwise they are unreadable jumping too fast up and down and stuff to read
#define ROLLING_WINDOW 120

void *PLAT_cpu_monitor(void *arg) {
    if (!Perf_tryBeginCPUMonitor()) return NULL;

    double prev_real_time = get_time_sec();
    double prev_cpu_time = get_process_cpu_time_sec();

    double cpu_usage_history[ROLLING_WINDOW] = {0};
    int history_index = 0;
    int history_count = 0;

    while (Perf_isCPUMonitorEnabled()) {
        double curr_real_time = get_time_sec();
        double curr_cpu_time = get_process_cpu_time_sec();

        double elapsed_real_time = curr_real_time - prev_real_time;
        double elapsed_cpu_time = curr_cpu_time - prev_cpu_time;

        if (elapsed_real_time > 0) {
            double cpu_usage = (elapsed_cpu_time / elapsed_real_time) * 100.0;

            pthread_mutex_lock(&currentcpuinfo);

            cpu_usage_history[history_index] = cpu_usage;
            history_index = (history_index + 1) % ROLLING_WINDOW;
            if (history_count < ROLLING_WINDOW) history_count++;

            double sum_cpu_usage = 0;
            for (int i = 0; i < history_count; i++) sum_cpu_usage += cpu_usage_history[i];
            perf.cpu_usage = sum_cpu_usage / history_count;

            pthread_mutex_unlock(&currentcpuinfo);
        }

        prev_real_time = curr_real_time;
        prev_cpu_time = curr_cpu_time;
        usleep(100000);
    }

    Perf_endCPUMonitor();
    return NULL;
}


void PLAT_setCPUSpeed(int speed) {
	const char* mode;
	char script[512];
	switch (speed) {
		case CPU_SPEED_AUTO: mode = "smart"; break;
		case CPU_SPEED_PERFORMANCE: mode = "performance"; break;
		case CPU_SPEED_POWERSAVE: mode = "idle"; break;
		default: return;
	}

	if (access("/usr/sbin/zlyme-governor", X_OK) == 0)
		snprintf(script, sizeof(script), "/usr/sbin/zlyme-governor");
	else if (access("/usr/share/nextui/bin/governor.sh", X_OK) == 0)
		snprintf(script, sizeof(script), "/usr/share/nextui/bin/governor.sh");
	else {
		const char* system_path = getenv("SYSTEM_PATH");
		if (!system_path) {
			LOG_info("WARNING: governor script missing\n");
			return;
		}
		int n = snprintf(script, sizeof(script), "%s/bin/governor.sh", system_path);
		if (n < 0 || n >= (int)sizeof(script) || access(script, X_OK) != 0) {
			LOG_info("WARNING: SYSTEM_PATH governor missing\n");
			return;
		}
	}
	char cmd[640];
	int n = snprintf(cmd, sizeof(cmd), "sh \"%s\" \"%s\"", script, mode);
	if (n < 0 || n >= (int)sizeof(cmd)) {
		LOG_info("WARNING: governor command too long\n");
		return;
	}
	int ret = system(cmd);
	if (ret != 0) LOG_info("WARNING: governor script exited with status %d for mode '%s'\n", ret, mode);
}


/* FF rumble on Miyoo Flip Gamepad. Any other FF_RUMBLE device is only a generic fallback. */
static int rumble_fd = -1;
static int rumble_id = -1;

static int rumble_has_ff(int fd)
{
	unsigned long bits[(FF_MAX / (sizeof(unsigned long) * 8)) + 1];
	unsigned shift = (unsigned)(sizeof(unsigned long) * 8);

	memset(bits, 0, sizeof(bits));
	if (ioctl(fd, EVIOCGBIT(EV_FF, sizeof(bits)), bits) < 0)
		return 0;
	return (bits[FF_RUMBLE / shift] >> (FF_RUMBLE % shift)) & 1UL;
}

static int rumble_open(void)
{
	DIR *dir;
	struct dirent *de;
	int exact = -1;
	int generic = -1;
	char name[256];

	if (rumble_fd >= 0)
		return 0;
	dir = opendir("/dev/input");
	if (!dir)
		return -1;
	while ((de = readdir(dir))) {
		char path[64];
		int fd;
		int got_name;

		if (strncmp(de->d_name, "event", 5) != 0)
			continue;
		snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);
		fd = open(path, O_RDWR | O_CLOEXEC);
		if (fd < 0)
			continue;
		if (!rumble_has_ff(fd)) {
			close(fd);
			continue;
		}
		memset(name, 0, sizeof(name));
		got_name = ioctl(fd, EVIOCGNAME(sizeof(name) - 1), name) >= 0;
		if (got_name && strcmp(name, "Miyoo Flip Gamepad") == 0) {
			if (exact < 0)
				exact = fd;
			else
				close(fd);
		} else if (generic < 0) {
			generic = fd;
		} else {
			close(fd);
		}
	}
	closedir(dir);

	if (exact >= 0) {
		if (generic >= 0)
			close(generic);
		rumble_fd = exact;
	} else if (generic >= 0) {
		rumble_fd = generic;
	} else {
		return -1;
	}

	rumble_id = -1;
	memset(name, 0, sizeof(name));
	if (ioctl(rumble_fd, EVIOCGNAME(sizeof(name) - 1), name) < 0 || name[0] == '\0')
		snprintf(name, sizeof(name), "unknown");
	LOG_info("rumble: using %s\n", name);
	return 0;
}

void PLAT_setRumble(int strength) {
	struct ff_effect e;
	struct input_event ev;

	if (strength < 0)
		strength = 0;
	if (strength > 0xffff)
		strength = 0xffff;
	if (rumble_open() < 0)
		return;

	if (strength == 0) {
		if (rumble_id < 0)
			return;
		memset(&ev, 0, sizeof(ev));
		ev.type = EV_FF;
		ev.code = (uint16_t)rumble_id;
		ev.value = 0;
		write(rumble_fd, &ev, sizeof(ev));
		return;
	}

	memset(&e, 0, sizeof(e));
	e.type = FF_RUMBLE;
	e.id = rumble_id;
	e.u.rumble.strong_magnitude = (uint16_t)strength;
	e.u.rumble.weak_magnitude = (uint16_t)strength;
	e.replay.length = 5000;
	if (ioctl(rumble_fd, EVIOCSFF, &e) < 0)
		return;
	rumble_id = e.id;
	memset(&ev, 0, sizeof(ev));
	ev.type = EV_FF;
	ev.code = (uint16_t)rumble_id;
	ev.value = 1;
	write(rumble_fd, &ev, sizeof(ev));
}

int PLAT_pickSampleRate(int requested, int max) {
	// bluetooth: allow limiting the maximum to improve compatibility
	if(PLAT_bluetoothConnected())
		return MIN(requested, CFG_getBluetoothSamplingrateLimit());

	return MIN(requested, max);
}

char* PLAT_getModel(void) {
	return "Miyoo Flip";
}

void PLAT_getOsVersionInfo(char* output_str, size_t max_len)
{
	return getFile("/etc/os-release", output_str,max_len);
}

bool PLAT_btIsConnected(void)
{
	return bluetoothConnected;
}

ConnectionStrength PLAT_connectionStrength(void) {
	if(!WIFI_enabled() || !connection.valid || connection.rssi == -1)
		return SIGNAL_STRENGTH_OFF;
	else if (connection.rssi == 0)
		return SIGNAL_STRENGTH_DISCONNECTED;
	else if (connection.rssi >= -60)
		return SIGNAL_STRENGTH_HIGH;
	else if (connection.rssi >= -70)
		return SIGNAL_STRENGTH_MED;
	else
		return SIGNAL_STRENGTH_LOW;
}

//////////////////////////////////////////////

int PLAT_setDateTime(int y, int m, int d, int h, int i, int s) {
	char cmd[512];
	sprintf(cmd, "date -s '%d-%d-%d %d:%d:%d'; hwclock -u -w", y,m,d,h,i,s);
	system(cmd);
	return 0; // why does this return an int?
}

#define MAX_LINE_LENGTH 200
#define ZONE_PATH "/usr/share/zoneinfo"
#define ZONE_TAB_PATH ZONE_PATH "/zone.tab"
#define ZONE_TAB_FALLBACK "/usr/share/nextui/zone.tab"
#define CUR_ZONE_PATH "/storage/.config/nextui/shared/localtime"

static char cached_timezones[MAX_TIMEZONES][MAX_TZ_LENGTH];
static int cached_tz_count = -1;

int compare_timezones(const void *a, const void *b) {
    return strcmp((const char *)a, (const char *)b);
}

void PLAT_initTimezones() {
    if (cached_tz_count != -1) { // Already initialized
        return;
    }
    
    FILE *file = fopen(ZONE_TAB_PATH, "r");
    if (!file)
        file = fopen(ZONE_TAB_FALLBACK, "r");
    if (!file) {
        LOG_info("Error opening file %s\n", ZONE_TAB_PATH);
        return;
    }
    
    char line[MAX_LINE_LENGTH];
    cached_tz_count = 0;
    
    while (fgets(line, sizeof(line), file)) {
        // Skip comment lines
        if (line[0] == '#' || strlen(line) < 3) {
            continue;
        }
        
        char *token = strtok(line, "\t"); // Skip country code
        if (!token) continue;
        
        token = strtok(NULL, "\t"); // Skip latitude/longitude
        if (!token) continue;
        
        token = strtok(NULL, "\t\n"); // Extract timezone
        if (!token) continue;
        
        // Check for duplicates before adding
        int duplicate = 0;
        for (int i = 0; i < cached_tz_count; i++) {
            if (strcmp(cached_timezones[i], token) == 0) {
                duplicate = 1;
                break;
            }
        }
        
        if (!duplicate && cached_tz_count < MAX_TIMEZONES) {
            strncpy(cached_timezones[cached_tz_count], token, MAX_TZ_LENGTH - 1);
            cached_timezones[cached_tz_count][MAX_TZ_LENGTH - 1] = '\0'; // Ensure null-termination
            cached_tz_count++;
        }
    }
    
    fclose(file);
    
    // Sort the list alphabetically
    qsort(cached_timezones, cached_tz_count, MAX_TZ_LENGTH, compare_timezones);
}

void PLAT_getTimezones(char timezones[MAX_TIMEZONES][MAX_TZ_LENGTH], int *tz_count) {
    if (cached_tz_count == -1) {
        LOG_warn("Error: Timezones not initialized. Call PLAT_initTimezones first.\n");
        *tz_count = 0;
        return;
    }
    
    memcpy(timezones, cached_timezones, sizeof(cached_timezones));
    *tz_count = cached_tz_count;
}

char *PLAT_getCurrentTimezone() {
	// easy enough, get current index from config and return the string
	int tz_index = CFG_getCurrentTimezone();
	if (tz_index < 0 || cached_tz_count <= 0 || tz_index >= cached_tz_count) {
		LOG_warn("Error: Current timezone index %d out of bounds.\n", tz_index);
		return strdup("UTC");
	}

	char *output = (char *)malloc(256);
	if (!output)
		return NULL;

	strncpy(output, cached_timezones[tz_index], 256 - 1);
	output[256 - 1] = '\0'; // Ensure null-termination

	return output;
}

void PLAT_setCurrentTimezone(const char* tz) {
	if (cached_tz_count == -1) {
		LOG_warn("Error: Timezones not initialized. Call PLAT_initTimezones first.\n");
        return;
    }

	if(!tz || strlen(tz) == 0) {
		LOG_warn("Error: Invalid timezone string.\n");
		return;
	}

	// get index of timezone
	int tz_index = -1;
	for (int i = 0; i < cached_tz_count; i++) {
		if (strcmp(cached_timezones[i], tz) == 0) {
			tz_index = i;
			break;
		}
	}

	if (tz_index == -1) {
		LOG_warn("Error: Timezone %s not found in cached list.\n", tz);
		return;
	}

	// set in config
	CFG_setCurrentTimezone(tz_index);

	// This fixes the timezone until the next reboot
	char *tz_path = (char *)malloc(256);
	if (!tz_path) {
		return;
	}
	snprintf(tz_path, 256, ZONE_PATH "/%s", tz);
	// replace existing
	char cmd[512];
	snprintf(cmd, 512, "cp %s %s", tz_path, CUR_ZONE_PATH);
	system(cmd);
	free(tz_path);

	// Settings timezone row only. GFX_init no longer calls this.
	system("hwclock -u -w && hwclock --systz -u");
}

bool PLAT_getNetworkTimeSync(void) {
	return CFG_getNTP();
}

void PLAT_setNetworkTimeSync(bool on) {
	(void)on;
	/* Clock comes from S49ntp after Wi-Fi. No Settings switch. */
}

/////////////////////////

// We use the generic video implementation here
#include "generic_video.c"

/////////////////////////

// We use the generic wifi implementation here

#define WIFI_SOCK_DIR "/var/run/wpa_supplicant"
#include "generic_wifi.c"

/////////////////////////

// We use the generic bluetooth implementation here
#include "generic_bt.c"
