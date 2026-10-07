/* SPDX-License-Identifier: MIT */
/*
 * One-shot ZLYMEBOOT marker decision. U-Boot copies this header next to
 * cmd/my355.c. The host test includes the same file. No filesystem calls
 * live here: the caller supplies them, and each call may close the volume.
 */
#ifndef MASKROM_REQUEST_H
#define MASKROM_REQUEST_H

#include <stddef.h>
#include <string.h>

#define ZLYME_MASKROM_MAGIC "ZLYME-MASKROM-1"
#define ZLYME_MASKROM_PATH "/zlyme-maskrom.request"

enum {
	/* No marker, or the boot volume could not be opened. */
	MASKROM_BOOT = 0,
	/* Marker consumed and proven gone. Caller may rbrom. */
	MASKROM_ENTER = 1,
	/* A file was there and was not proven gone. Do not rbrom. */
	MASKROM_REJECT = 2
};

struct maskrom_fs {
	/* 0 when the primary ZLYMEBOOT volume is open. */
	int (*open_volume)(void);
	/* 1 present, 0 absent, negative on error. */
	int (*exists)(void);
	/* 0 and *out set to the byte length. */
	int (*size)(int *out);
	/* 0 and *nread set. */
	int (*read)(void *buf, int len, int *nread);
	/* 0 when the marker was deleted. */
	int (*unlink)(void);
	const char *magic;
	int magic_len;
};

/*
 * Delete a marker only after its bytes match exactly, and report ENTER
 * only after a later exists() says it is gone. A wrong or empty file is
 * left in place.
 */
static inline int maskrom_request_consume(const struct maskrom_fs *fs)
{
	char buf[32];
	int size = 0;
	int nread = 0;
	int exists;

	if (!fs || !fs->open_volume || !fs->exists || !fs->size ||
	    !fs->read || !fs->unlink || !fs->magic ||
	    fs->magic_len <= 0 || fs->magic_len >= (int)sizeof(buf))
		return MASKROM_BOOT;
	if (fs->open_volume() != 0)
		return MASKROM_BOOT;
	exists = fs->exists();
	if (exists == 0)
		return MASKROM_BOOT;
	if (exists != 1)
		return MASKROM_BOOT;

	if (fs->open_volume() != 0)
		return MASKROM_REJECT;
	if (fs->size(&size) != 0 || size != fs->magic_len)
		return MASKROM_REJECT;
	if (fs->open_volume() != 0)
		return MASKROM_REJECT;
	if (fs->read(buf, fs->magic_len, &nread) != 0 || nread != fs->magic_len)
		return MASKROM_REJECT;
	if (memcmp(buf, fs->magic, (size_t)fs->magic_len) != 0)
		return MASKROM_REJECT;
	if (fs->open_volume() != 0)
		return MASKROM_REJECT;
	if (fs->unlink() != 0)
		return MASKROM_REJECT;
	if (fs->open_volume() != 0)
		return MASKROM_REJECT;
	if (fs->exists() != 0)
		return MASKROM_REJECT;
	return MASKROM_ENTER;
}

#endif
