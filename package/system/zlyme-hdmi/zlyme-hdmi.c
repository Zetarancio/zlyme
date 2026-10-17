#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "hdmi_mode.h"

#include <xf86drm.h>
#include <xf86drmMode.h>

#include <ctype.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MODE_MAX 64
#define CONN_MAX 8

struct stored_mode {
	struct zlyme_hdmi_mode mode;
};

struct stored_conn {
	struct zlyme_hdmi_connector pub;
	struct stored_mode modes[MODE_MAX];
	char name[32];
};

static int gate_on(void)
{
	const char *flag = getenv("ZLYME_HDMI_720P");

	return flag && flag[0] == '1' && flag[1] == '\0';
}

static void trace_open(void)
{
	if (getenv("ZLYME_HDMI_TRACE"))
		fprintf(stderr, "drm-open\n");
}

static int name_ok(const char *name)
{
	int i;

	if (!name || !name[0] || strlen(name) > 31)
		return 0;
	for (i = 0; name[i]; i++) {
		unsigned char c = (unsigned char)name[i];

		if (!isalnum(c) && c != '-' && c != '_' && c != '.')
			return 0;
	}
	return 1;
}

static const char *mode_path(void)
{
	const char *path = getenv("ZLYME_HDMI_MODE_PATH");

	if (path && path[0])
		return path;
	return "/run/zlyme/hdmi.mode";
}

static void clear_mode_file(void)
{
	unlink(mode_path());
}

static void print_inactive(void)
{
	clear_mode_file();
	printf("ZLYME_HDMI_ACTIVE=0\n");
	printf("unset ZLYME_HDMI_SDL_MODE\n");
	printf("unset ZLYME_HDMI_SDL_CONNECTOR\n");
	printf("unset ZLYME_HDMI_WIDTH\n");
	printf("unset ZLYME_HDMI_HEIGHT\n");
	printf("unset ZLYME_HDMI_CONNECTOR\n");
	printf("unset ZLYME_HDMI_CARD\n");
	printf("unset ZLYME_HDMI_VREFRESH\n");
	printf("unset ZLYME_HDMI_REFRESH_HZ\n");
	printf("unset ZLYME_HDMI_MONITOR\n");
	printf("unset ZLYME_HDMI_CONNECTOR_ID\n");
}

static int sdl_refresh(const struct zlyme_hdmi_output *out)
{
	if (out->vrefresh > 0)
		return out->vrefresh;
	return (out->choice.refresh_mhz + 500) / 1000;
}

static int write_mode_file(const struct zlyme_hdmi_output *out, int hz)
{
	const char *path = mode_path();
	char tmp[256];
	FILE *fp;
	int n;

	n = snprintf(tmp, sizeof(tmp), "%s.tmp", path);
	if (n < 0 || n >= (int)sizeof(tmp))
		return -1;
	fp = fopen(tmp, "w");
	if (!fp)
		return -1;
	fprintf(fp, "active=1\n");
	fprintf(fp, "card=%d\n", out->card);
	fprintf(fp, "connector=%s\n", out->name);
	fprintf(fp, "connector_id=%d\n", out->connector_id);
	fprintf(fp, "width=%d\n", out->choice.width);
	fprintf(fp, "height=%d\n", out->choice.height);
	fprintf(fp, "refresh_mhz=%d\n", out->choice.refresh_mhz);
	fprintf(fp, "vrefresh=%d\n", hz);
	fprintf(fp, "monitor_index=%d\n", out->monitor_index);
	if (fclose(fp) != 0) {
		unlink(tmp);
		return -1;
	}
	if (rename(tmp, path) != 0) {
		unlink(tmp);
		return -1;
	}
	return 0;
}

static void print_active(const struct zlyme_hdmi_output *out)
{
	int hz = sdl_refresh(out);

	write_mode_file(out, hz);
	printf("ZLYME_HDMI_ACTIVE=1\n");
	printf("ZLYME_HDMI_CARD=%d\n", out->card);
	printf("ZLYME_HDMI_CONNECTOR='%s'\n", out->name);
	printf("ZLYME_HDMI_CONNECTOR_ID=%d\n", out->connector_id);
	printf("ZLYME_HDMI_WIDTH=%d\n", out->choice.width);
	printf("ZLYME_HDMI_HEIGHT=%d\n", out->choice.height);
	printf("ZLYME_HDMI_VREFRESH=%d\n", hz);
	printf("ZLYME_HDMI_REFRESH_HZ=%d.%03d\n",
	       out->choice.refresh_mhz / 1000, out->choice.refresh_mhz % 1000);
	printf("ZLYME_HDMI_MONITOR=%d\n", out->monitor_index);
	printf("ZLYME_HDMI_SDL_CONNECTOR=%d\n", out->connector_id);
	printf("ZLYME_HDMI_SDL_MODE='%dx%d@%d'\n",
	       out->choice.width, out->choice.height, hz);
}

static int add_mode(struct stored_conn *conn, int width, int height,
		    int refresh_mhz, int vrefresh, int preferred)
{
	struct zlyme_hdmi_mode *mode;

	if (conn->pub.count >= MODE_MAX)
		return -1;
	mode = &conn->modes[conn->pub.count].mode;
	mode->width = width;
	mode->height = height;
	mode->refresh_mhz = refresh_mhz;
	mode->vrefresh = vrefresh;
	mode->preferred = preferred ? 1 : 0;
	conn->pub.count++;
	return 0;
}

static int load_fixture(struct stored_conn *cons, int *ncons)
{
	const char *path = getenv("ZLYME_HDMI_FIXTURE");
	FILE *fp;
	char line[256];
	int cur = -1;
	int monitors[2] = { 0, 0 };

	if (!path || !path[0])
		return 0;
	fp = fopen(path, "r");
	if (!fp)
		return -1;
	*ncons = 0;
	while (fgets(line, sizeof(line), fp)) {
		char name[32];
		char type[16];
		int card, id, connected, w, h, mhz, vref, pref;

		if (line[0] == '#' || line[0] == '\n')
			continue;
		if (sscanf(line,
			   "connector card=%d id=%d name=%31s type=%15s connected=%d",
			   &card, &id, name, type, &connected) == 5) {
			if (*ncons >= CONN_MAX || !name_ok(name)) {
				fclose(fp);
				return -1;
			}
			cur = *ncons;
			memset(&cons[cur], 0, sizeof(cons[cur]));
			cons[cur].pub.card = card;
			cons[cur].pub.connector_id = id;
			cons[cur].pub.hdmia = strcmp(type, "hdmia") == 0;
			cons[cur].pub.connected = connected ? 1 : 0;
			snprintf(cons[cur].name, sizeof(cons[cur].name), "%s", name);
			cons[cur].pub.name = cons[cur].name;
			cons[cur].pub.modes = &cons[cur].modes[0].mode;
			if (connected && card >= 0 && card < 2) {
				monitors[card]++;
				cons[cur].pub.monitor_index = monitors[card];
			}
			(*ncons)++;
			continue;
		}
		if (sscanf(line, "mode %d %d %d %d %d", &w, &h, &mhz, &vref, &pref) == 5) {
			if (cur < 0 || add_mode(&cons[cur], w, h, mhz, vref, pref) != 0) {
				fclose(fp);
				return -1;
			}
			continue;
		}
		fclose(fp);
		return -1;
	}
	fclose(fp);
	return 1;
}

static void connector_name(drmModeConnector *conn, char *dst, size_t len)
{
	const char *kind = "UNK";
	int index = conn->connector_type_id;

	if (conn->connector_type == DRM_MODE_CONNECTOR_HDMIA)
		kind = "HDMI-A";
	else if (conn->connector_type == DRM_MODE_CONNECTOR_DSI)
		kind = "DSI";
	snprintf(dst, len, "%s-%d", kind, index > 0 ? index : 1);
}

static int open_card(int card, int *rdwr)
{
	char path[64];
	int fd;
	drmModeRes *res;

	snprintf(path, sizeof(path), "/dev/dri/card%d", card);
	*rdwr = 0;
	trace_open();
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd >= 0) {
		res = drmModeGetResources(fd);
		if (res) {
			drmModeFreeResources(res);
			return fd;
		}
		close(fd);
	}
	trace_open();
	fd = open(path, O_RDWR | O_CLOEXEC);
	if (fd < 0)
		return -1;
	*rdwr = 1;
	return fd;
}

static int load_drm(struct stored_conn *cons, int *ncons)
{
	int card;

	*ncons = 0;
	for (card = 0; card < 2; card++) {
		int fd, rdwr = 0;
		drmModeRes *res;
		int i;
		int monitors = 0;

		fd = open_card(card, &rdwr);
		if (fd < 0)
			continue;
		res = drmModeGetResources(fd);
		if (!res) {
			if (rdwr && drmIsMaster(fd) == 1)
				drmDropMaster(fd);
			close(fd);
			continue;
		}
		for (i = 0; i < res->count_connectors && *ncons < CONN_MAX; i++) {
			drmModeConnector *conn;
			int m;
			struct stored_conn *dst;

			conn = drmModeGetConnector(fd, res->connectors[i]);
			if (!conn)
				continue;
			dst = &cons[*ncons];
			memset(dst, 0, sizeof(*dst));
			dst->pub.card = card;
			dst->pub.connector_id = (int)conn->connector_id;
			dst->pub.hdmia = conn->connector_type == DRM_MODE_CONNECTOR_HDMIA;
			dst->pub.connected = conn->connection == DRM_MODE_CONNECTED &&
					     conn->count_modes > 0;
			connector_name(conn, dst->name, sizeof(dst->name));
			dst->pub.name = dst->name;
			dst->pub.modes = &dst->modes[0].mode;
			if (dst->pub.connected) {
				monitors++;
				dst->pub.monitor_index = monitors;
				for (m = 0; m < conn->count_modes; m++) {
					drmModeModeInfo *mode = &conn->modes[m];
					int mhz = zlyme_hdmi_refresh_mhz(
						mode->clock, mode->htotal, mode->vtotal);

					if (mhz <= 0 && mode->vrefresh > 0)
						mhz = mode->vrefresh * 1000;
					add_mode(dst, mode->hdisplay, mode->vdisplay, mhz,
						 mode->vrefresh,
						 (mode->type & DRM_MODE_TYPE_PREFERRED) ? 1 : 0);
				}
			}
			drmModeFreeConnector(conn);
			if (dst->pub.connected || dst->pub.hdmia)
				(*ncons)++;
		}
		drmModeFreeResources(res);
		if (rdwr && drmIsMaster(fd) == 1)
			drmDropMaster(fd);
		close(fd);
	}
	return 0;
}

int main(void)
{
	struct stored_conn cons[CONN_MAX];
	struct zlyme_hdmi_connector pubs[CONN_MAX];
	struct zlyme_hdmi_output out;
	int n = 0;
	int i;
	int fixture;

	if (!gate_on()) {
		print_inactive();
		return 0;
	}
	fixture = load_fixture(cons, &n);
	if (fixture < 0) {
		print_inactive();
		return 1;
	}
	if (!fixture && load_drm(cons, &n) != 0) {
		print_inactive();
		return 1;
	}
	for (i = 0; i < n; i++) {
		pubs[i] = cons[i].pub;
		pubs[i].modes = &cons[i].modes[0].mode;
		pubs[i].name = cons[i].name;
	}
	if (zlyme_hdmi_pick(pubs, n, &out) < 0 || !name_ok(out.name)) {
		print_inactive();
		return 0;
	}
	print_active(&out);
	return 0;
}
