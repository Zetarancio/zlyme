/*
 * Blit a 640x480 RGB565 splash onto /dev/fb0 (16 or 32 bpp).
 * Optional anim loops until SIGTERM. A live mmap of fb0 blocks KMSDRM.
 *
 * A second still+anim (galaxy) is the resize/OTA lockup. Same size and
 * place as the slime so we can switch without killing this process.
 * touch /tmp/zlyme-splash.progress (or the FAT flag) to flip.
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

struct still {
	uint16_t *pix;
	int ok;
};

struct anim {
	uint8_t *buf;
	const uint16_t *pix;
	int ax, ay, aw, ah, nframes, delay;
	int ok;
};

static volatile sig_atomic_t g_run = 1;
static volatile sig_atomic_t g_force_progress = 0;
static volatile sig_atomic_t g_force_boot = 0;

static void on_stop(int sig)
{
	(void)sig;
	g_run = 0;
}

static void on_progress(int sig)
{
	(void)sig;
	g_force_progress = 1;
	g_force_boot = 0;
}

static void on_bootlogo(int sig)
{
	(void)sig;
	g_force_boot = 1;
	g_force_progress = 0;
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
	size_t got;
	ssize_t n;

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
	got = 0;
	while (got < (size_t)st.st_size) {
		n = read(fd, buf + got, (size_t)st.st_size - got);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			free(buf);
			close(fd);
			return NULL;
		}
		if (n == 0)
			break;
		got += (size_t)n;
	}
	close(fd);
	if (got != (size_t)st.st_size) {
		free(buf);
		return NULL;
	}
	*len = got;
	return buf;
}

static uint16_t le16(const uint8_t *p)
{
	return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static int file_ok(const char *path)
{
	return path && path[0] && access(path, R_OK) == 0;
}

static int load_still(const char *path, struct still *out);
static int load_anim(const char *path, struct anim *out);

static int progress_flag(void)
{
	static const char *const flags[] = {
		"/tmp/zlyme-splash.progress",
		"/boot/zlyme-splash.progress",
		"/boot_root/zlyme-splash.progress",
		"/zlyme-splash.progress",
		NULL,
	};
	int i;

	for (i = 0; flags[i]; i++) {
		if (access(flags[i], F_OK) == 0)
			return 1;
	}
	return 0;
}

static int progress_wanted(int start_progress)
{
	if (g_force_boot)
		return 0;
	if (g_force_progress || start_progress)
		return 1;
	return progress_flag();
}

static const char *pick_readable(const char *const *paths)
{
	int i;

	for (i = 0; paths[i]; i++) {
		if (file_ok(paths[i]))
			return paths[i];
	}
	return NULL;
}

static int try_load_still_paths(struct still *out, const char *const *paths)
{
	const char *p;

	if (out->ok)
		return 1;
	p = pick_readable(paths);
	if (!p)
		return 0;
	return load_still(p, out);
}

static int try_load_anim_paths(struct anim *out, const char *const *paths)
{
	const char *p;

	if (out->ok)
		return 1;
	p = pick_readable(paths);
	if (!p)
		return 0;
	return load_anim(p, out);
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

static int load_still(const char *path, struct still *out)
{
	size_t len = 0;
	size_t want = (size_t)SPLASH_W * SPLASH_H * 2;

	memset(out, 0, sizeof(*out));
	out->pix = (uint16_t *)load_file(path, &len);
	if (!out->pix || len < want) {
		free(out->pix);
		out->pix = NULL;
		return 0;
	}
	out->ok = 1;
	return 1;
}

static int load_anim(const char *path, struct anim *out)
{
	size_t len = 0;

	memset(out, 0, sizeof(*out));
	out->buf = load_file(path, &len);
	if (!out->buf || len < ANIM_HDR || memcmp(out->buf, ANIM_MAGIC, 4) != 0 ||
	    le16(out->buf + 4) != 1) {
		free(out->buf);
		out->buf = NULL;
		return 0;
	}
	out->ax = le16(out->buf + 6);
	out->ay = le16(out->buf + 8);
	out->aw = le16(out->buf + 10);
	out->ah = le16(out->buf + 12);
	out->nframes = le16(out->buf + 14);
	out->delay = le16(out->buf + 16);
	if (out->delay < 20)
		out->delay = 20;
	if (out->aw <= 0 || out->ah <= 0 || out->nframes <= 0 ||
	    out->ax + out->aw > SPLASH_W || out->ay + out->ah > SPLASH_H ||
	    len < ANIM_HDR + (size_t)out->nframes * out->aw * out->ah * 2) {
		free(out->buf);
		out->buf = NULL;
		return 0;
	}
	out->pix = (const uint16_t *)(out->buf + ANIM_HDR);
	out->ok = 1;
	return 1;
}

int main(int argc, char **argv)
{
	const char *still_path = argc > 1 ? argv[1] : "/splash.rgb565";
	const char *anim_path = argc > 2 ? argv[2] : "/splash.anim";
	const char *pstill_path = argc > 3 ? argv[3] : "/progress.rgb565";
	const char *panim_path = argc > 4 ? argv[4] : "/progress.anim";
	int start_progress = argc > 5 && strcmp(argv[5], "progress") == 0;
	int fd, bpp, x0, y0, frame, i, use_progress, want;
	struct fb_var_screeninfo v;
	struct fb_fix_screeninfo f;
	struct still boot_still, prog_still;
	struct anim boot_anim, prog_anim;
	uint8_t *fb;
	size_t fb_len;
	uint32_t line;
	const struct still *cur_still;
	const struct anim *cur_anim;
	const char *boot_still_paths[] = {
		still_path,
		"/splash.rgb565",
		"/usr/share/zlyme/splash.rgb565",
		NULL,
	};
	const char *boot_anim_paths[] = {
		anim_path,
		"/boot_root/splash.anim",
		"/boot/splash.anim",
		"/usr/share/zlyme/splash.anim",
		"/new_root/boot/splash.anim",
		"/new_root/usr/share/zlyme/splash.anim",
		NULL,
	};
	const char *prog_still_paths[] = {
		pstill_path,
		"/progress.rgb565",
		"/usr/share/zlyme/progress.rgb565",
		"/new_root/usr/share/zlyme/progress.rgb565",
		NULL,
	};
	const char *prog_anim_paths[] = {
		panim_path,
		"/boot_root/progress.anim",
		"/boot/progress.anim",
		"/usr/share/zlyme/progress.anim",
		"/new_root/boot/progress.anim",
		"/new_root/usr/share/zlyme/progress.anim",
		NULL,
	};

	memset(&boot_still, 0, sizeof(boot_still));
	memset(&prog_still, 0, sizeof(prog_still));
	memset(&boot_anim, 0, sizeof(boot_anim));
	memset(&prog_anim, 0, sizeof(prog_anim));

	signal(SIGTERM, on_stop);
	signal(SIGINT, on_stop);
	signal(SIGHUP, on_stop);
	signal(SIGUSR1, on_progress);
	signal(SIGUSR2, on_bootlogo);

	if (!try_load_still_paths(&boot_still, boot_still_paths))
		return 1;

	fd = open_fb();
	if (fd < 0) {
		free(boot_still.pix);
		free(prog_still.pix);
		free(boot_anim.buf);
		free(prog_anim.buf);
		return 1;
	}
	memset(&v, 0, sizeof(v));
	memset(&f, 0, sizeof(f));
	if (ioctl(fd, FBIOGET_VSCREENINFO, &v) < 0 ||
	    ioctl(fd, FBIOGET_FSCREENINFO, &f) < 0) {
		free(boot_still.pix);
		free(prog_still.pix);
		free(boot_anim.buf);
		free(prog_anim.buf);
		close(fd);
		return 1;
	}
	bpp = v.bits_per_pixel;
	line = f.line_length;
	if (!line)
		line = (uint32_t)v.xres_virtual * ((bpp + 7) / 8);
	if (v.xres < 1 || v.yres < 1 || line < 1) {
		free(boot_still.pix);
		free(prog_still.pix);
		free(boot_anim.buf);
		free(prog_anim.buf);
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
		free(boot_still.pix);
		free(prog_still.pix);
		free(boot_anim.buf);
		free(prog_anim.buf);
		close(fd);
		return 1;
	}

	x0 = ((int)v.xres - SPLASH_W) / 2;
	y0 = ((int)v.yres - SPLASH_H) / 2;
	/* First paint is the ramdisk still. Do not wait on a 20+ MB
	 * anim read. Galaxy still is small; load it now only if this
	 * process started as the resize/OTA lockup.
	 */
	if (progress_wanted(start_progress))
		try_load_still_paths(&prog_still, prog_still_paths);
	use_progress = progress_wanted(start_progress) && prog_still.ok;
	cur_still = use_progress ? &prog_still : &boot_still;
	cur_anim = NULL;
	blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres, x0, y0,
		    cur_still->pix, SPLASH_W, SPLASH_H);
	frame = 0;
	try_load_anim_paths(&boot_anim, boot_anim_paths);
	if (use_progress)
		try_load_anim_paths(&prog_anim, prog_anim_paths);
	cur_anim = (use_progress && prog_anim.ok) ? &prog_anim :
		   (boot_anim.ok ? &boot_anim : NULL);
	if (cur_anim) {
		blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres,
			    x0 + cur_anim->ax, y0 + cur_anim->ay,
			    cur_anim->pix, cur_anim->aw, cur_anim->ah);
		frame = 1;
		if (frame >= cur_anim->nframes)
			frame = 0;
	}

	while (g_run) {
		try_load_anim_paths(&boot_anim, boot_anim_paths);
		want = progress_wanted(start_progress);
		if (want) {
			try_load_still_paths(&prog_still, prog_still_paths);
			try_load_anim_paths(&prog_anim, prog_anim_paths);
		}
		want = want && prog_still.ok;
		if (want != use_progress ||
		    (use_progress && prog_anim.ok && cur_anim != &prog_anim) ||
		    (!use_progress && boot_anim.ok && cur_anim != &boot_anim &&
		     !want)) {
			use_progress = want;
			cur_still = use_progress ? &prog_still : &boot_still;
			cur_anim = (use_progress && prog_anim.ok) ? &prog_anim :
				   (boot_anim.ok ? &boot_anim : NULL);
			blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres,
				    x0, y0, cur_still->pix, SPLASH_W, SPLASH_H);
			frame = 0;
		} else if (!cur_anim) {
			cur_anim = (use_progress && prog_anim.ok) ? &prog_anim :
				   (boot_anim.ok ? &boot_anim : NULL);
		}
		if (cur_anim) {
			i = frame * cur_anim->aw * cur_anim->ah;
			blit_rgb565(fb, line, bpp, (int)v.xres, (int)v.yres,
				    x0 + cur_anim->ax, y0 + cur_anim->ay,
				    cur_anim->pix + i, cur_anim->aw, cur_anim->ah);
			frame++;
			if (frame >= cur_anim->nframes)
				frame = 0;
			sleep_ms(cur_anim->delay);
		} else {
			sleep_ms(100);
		}
	}
	free(boot_still.pix);
	free(prog_still.pix);
	free(boot_anim.buf);
	free(prog_anim.buf);
	msync(fb, fb_len, MS_SYNC);
	munmap(fb, fb_len);
	close(fd);
	return 0;
}
