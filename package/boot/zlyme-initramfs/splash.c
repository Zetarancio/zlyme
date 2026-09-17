/*
 * Blit a 640x480 RGB565 splash onto /dev/fb0 (16 or 32 bpp).
 * Optional /splash.anim (glass overlay) loops until SIGTERM so init
 * can kill us before switch_root. A live mmap of fb0 blocks KMSDRM.
 */
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define SPLASH_W 640
#define SPLASH_H 480
#define ANIM_MAGIC "ZLYA"
#define ANIM_HDR 20

static volatile sig_atomic_t g_run = 1;

static void on_stop(int sig)
{
	(void)sig;
	g_run = 0;
}

static void sleep_ms(int ms)
{
	struct timespec ts = {
		.tv_sec = ms / 1000,
		.tv_nsec = (long)(ms % 1000) * 1000000L,
	};

	while (ms > 0 && g_run) {
		if (nanosleep(&ts, &ts) == 0)
			return;
		if (errno != EINTR)
			return;
	}
}

static int open_fb(void)
{
	int i, fd;

	for (i = 0; i < 40 && g_run; i++) {
		fd = open("/dev/fb0", O_RDWR);
		if (fd >= 0)
			return fd;
		sleep_ms(20);
	}
	return -1;
}

static uint8_t *load_file(const char *path, size_t *len)
{
	struct stat st;
	int fd;
	uint8_t *buf;

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return NULL;
	if (fstat(fd, &st) < 0 || st.st_size < 1) {
		close(fd);
		return NULL;
	}
	buf = malloc((size_t)st.st_size);
	if (!buf) {
		close(fd);
		return NULL;
	}
	if (read(fd, buf, (size_t)st.st_size) != st.st_size) {
		free(buf);
		close(fd);
		return NULL;
	}
	close(fd);
	*len = (size_t)st.st_size;
	return buf;
}

static uint16_t le16(const uint8_t *p)
{
	return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static void pix565(uint16_t p, uint8_t *r, uint8_t *g, uint8_t *b)
{
	*r = (uint8_t)(((p >> 11) & 31) * 255 / 31);
	*g = (uint8_t)(((p >> 5) & 63) * 255 / 63);
	*b = (uint8_t)((p & 31) * 255 / 31);
}

static void blit_px(uint8_t *fb, uint32_t line, int bpp,
		    int dx, int dy, uint16_t p)
{
	uint8_t r, g, b;
	uint8_t *dst = fb + (size_t)dy * line + (size_t)dx * ((bpp + 7) / 8);

	if (bpp == 16) {
		dst[0] = (uint8_t)(p & 0xff);
		dst[1] = (uint8_t)(p >> 8);
	} else if (bpp == 24) {
		pix565(p, &r, &g, &b);
		dst[0] = b;
		dst[1] = g;
		dst[2] = r;
	} else if (bpp >= 32) {
		pix565(p, &r, &g, &b);
		dst[0] = b;
		dst[1] = g;
		dst[2] = r;
		dst[3] = 0xff;
	}
}

static void blit_rgb565(uint8_t *fb, uint32_t line, int bpp,
		       int xres, int yres, int x0, int y0,
		       const uint16_t *src, int sw, int sh)
{
	int x, y;

	for (y = 0; y < sh; y++) {
		int dy = y0 + y;

		if (dy < 0 || dy >= yres)
			continue;
		for (x = 0; x < sw; x++) {
			int dx = x0 + x;

			if (dx < 0 || dx >= xres)
				continue;
			blit_px(fb, line, bpp, dx, dy, src[y * sw + x]);
		}
	}
}

int main(int argc, char **argv)
{
	const char *still_path = argc > 1 ? argv[1] : "/splash.rgb565";
	const char *anim_path = argc > 2 ? argv[2] : "/splash.anim";
	int fd;
	struct fb_var_screeninfo v;
	struct fb_fix_screeninfo f;
	uint8_t *fb, *anim;
	uint16_t *src;
	size_t still_len = 0, anim_len = 0, want, fb_len;
	int x0, y0, bpp, ax, ay, aw, ah, nframes, delay, i, frame;
	int have_anim = 0;
	uint32_t line;
	const uint16_t *apix = NULL;

	signal(SIGTERM, on_stop);
	signal(SIGINT, on_stop);
	signal(SIGHUP, on_stop);

	/* Read the still and lockup before touching fb0 so the first
	 * paint is already spinning, not a still wait for a 6 MB anim.
	 */
	want = (size_t)SPLASH_W * SPLASH_H * 2;
	src = (uint16_t *)load_file(still_path, &still_len);
	if (!src || still_len < want) {
		free(src);
		return 1;
	}
	anim = load_file(anim_path, &anim_len);
	if (anim && anim_len >= ANIM_HDR && memcmp(anim, ANIM_MAGIC, 4) == 0 &&
	    le16(anim + 4) == 1) {
		ax = le16(anim + 6);
		ay = le16(anim + 8);
		aw = le16(anim + 10);
		ah = le16(anim + 12);
		nframes = le16(anim + 14);
		delay = le16(anim + 16);
		if (delay < 20)
			delay = 20;
		if (aw > 0 && ah > 0 && nframes > 0 &&
		    ax + aw <= SPLASH_W && ay + ah <= SPLASH_H &&
		    anim_len >= ANIM_HDR + (size_t)nframes * aw * ah * 2) {
			apix = (const uint16_t *)(anim + ANIM_HDR);
			have_anim = 1;
		}
	}

	fd = open_fb();
	if (fd < 0) {
		free(src);
		free(anim);
		return 1;
	}
	memset(&v, 0, sizeof(v));
	memset(&f, 0, sizeof(f));
	if (ioctl(fd, FBIOGET_VSCREENINFO, &v) < 0 ||
	    ioctl(fd, FBIOGET_FSCREENINFO, &f) < 0) {
		free(src);
		free(anim);
		close(fd);
		return 1;
	}
	bpp = v.bits_per_pixel;
	line = f.line_length;
	if (!line)
		line = (uint32_t)v.xres_virtual * ((bpp + 7) / 8);
	if (v.xres < 1 || v.yres < 1 || line < 1) {
		free(src);
		free(anim);
		close(fd);
		return 1;
	}
	fb_len = (size_t)line * (v.yres_virtual > 0 ? v.yres_virtual : v.yres);
	fb = mmap(NULL, fb_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (fb == MAP_FAILED) {
		fb_len = (size_t)line * v.yres;
		fb = mmap(NULL, fb_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	}
	if (fb == MAP_FAILED) {
		free(src);
		free(anim);
		close(fd);
		return 1;
	}

	x0 = ((int)v.xres - SPLASH_W) / 2;
	y0 = ((int)v.yres - SPLASH_H) / 2;
	blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres, x0, y0,
		    src, SPLASH_W, SPLASH_H);
	free(src);
	src = NULL;
	if (have_anim) {
		blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres,
			    x0 + ax, y0 + ay, apix, aw, ah);
		frame = 1;
		if (frame >= nframes)
			frame = 0;
		while (g_run) {
			i = frame * aw * ah;
			blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres,
				    x0 + ax, y0 + ay, apix + i, aw, ah);
			frame++;
			if (frame >= nframes)
				frame = 0;
			sleep_ms(delay);
		}
	} else {
		while (g_run)
			sleep_ms(100);
	}
	free(anim);
	msync(fb, fb_len, MS_SYNC);
	munmap(fb, fb_len);
	close(fd);
	return 0;
}
