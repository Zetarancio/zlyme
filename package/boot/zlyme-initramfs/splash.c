/*
 * Blit a 640x480 RGB565 splash onto /dev/fb0 (16 or 32 bpp).
 * No libpng: the pixels are packed at build time.
 */
#include <fcntl.h>
#include <linux/fb.h>
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

static void sleep_ms(int ms)
{
	struct timespec ts = {
		.tv_sec = ms / 1000,
		.tv_nsec = (long)(ms % 1000) * 1000000L,
	};
	nanosleep(&ts, NULL);
}

static int open_fb(void)
{
	int i, fd;

	for (i = 0; i < 50; i++) {
		fd = open("/dev/fb0", O_RDWR);
		if (fd >= 0)
			return fd;
		sleep_ms(100);
	}
	return -1;
}

static uint16_t *load_rgb565(const char *path, size_t want)
{
	struct stat st;
	int fd;
	uint16_t *buf;

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return NULL;
	if (fstat(fd, &st) < 0 || (size_t)st.st_size < want) {
		close(fd);
		return NULL;
	}
	buf = malloc(want);
	if (!buf) {
		close(fd);
		return NULL;
	}
	if (read(fd, buf, want) != (ssize_t)want) {
		free(buf);
		close(fd);
		return NULL;
	}
	close(fd);
	return buf;
}

static void pix565(uint16_t p, uint8_t *r, uint8_t *g, uint8_t *b)
{
	*r = (uint8_t)(((p >> 11) & 31) * 255 / 31);
	*g = (uint8_t)(((p >> 5) & 63) * 255 / 63);
	*b = (uint8_t)((p & 31) * 255 / 31);
}

int main(int argc, char **argv)
{
	const char *path = argc > 1 ? argv[1] : "/splash.rgb565";
	int fd;
	struct fb_var_screeninfo v;
	struct fb_fix_screeninfo f;
	uint8_t *fb;
	uint16_t *src;
	size_t want = (size_t)SPLASH_W * SPLASH_H * 2;
	int x0, y0, x, y, bpp;
	uint32_t line;

	fd = open_fb();
	if (fd < 0)
		return 1;
	memset(&v, 0, sizeof(v));
	memset(&f, 0, sizeof(f));
	if (ioctl(fd, FBIOGET_VSCREENINFO, &v) < 0 ||
	    ioctl(fd, FBIOGET_FSCREENINFO, &f) < 0) {
		close(fd);
		return 1;
	}
	bpp = v.bits_per_pixel;
	line = f.line_length;
	if (!line)
		line = (uint32_t)v.xres_virtual * ((bpp + 7) / 8);
	if (v.xres < 1 || v.yres < 1 || line < 1) {
		close(fd);
		return 1;
	}
	fb = mmap(NULL, (size_t)line * v.yres_virtual, PROT_READ | PROT_WRITE,
		  MAP_SHARED, fd, 0);
	if (fb == MAP_FAILED) {
		fb = mmap(NULL, (size_t)line * v.yres, PROT_READ | PROT_WRITE,
			  MAP_SHARED, fd, 0);
	}
	if (fb == MAP_FAILED) {
		close(fd);
		return 1;
	}
	src = load_rgb565(path, want);
	if (!src) {
		munmap(fb, (size_t)line * v.yres);
		close(fd);
		return 1;
	}

	x0 = ((int)v.xres - SPLASH_W) / 2;
	y0 = ((int)v.yres - SPLASH_H) / 2;
	for (y = 0; y < SPLASH_H; y++) {
		int dy = y0 + y;
		if (dy < 0 || dy >= (int)v.yres)
			continue;
		for (x = 0; x < SPLASH_W; x++) {
			int dx = x0 + x;
			uint16_t p;
			uint8_t r, g, b;
			uint8_t *dst;

			if (dx < 0 || dx >= (int)v.xres)
				continue;
			p = src[y * SPLASH_W + x];
			dst = fb + (size_t)dy * line + (size_t)dx * ((bpp + 7) / 8);
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
	}

	free(src);
	msync(fb, (size_t)line * v.yres, MS_SYNC);
	munmap(fb, (size_t)line * v.yres);
	close(fd);
	return 0;
}
