/* Host fixture for the U-Boot marker decision. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "maskrom_request.h"

static char file[64];
static int file_set;
static int fail_open;
static int fail_unlink;
static int exists_after_unlink;
static char logbuf[256];
static int rbroms;

static void note(const char *s)
{
	if (strlen(logbuf) + strlen(s) + 2 < sizeof(logbuf)) {
		strcat(logbuf, s);
		strcat(logbuf, " ");
	}
}

static int t_open(void)
{
	note("open");
	return fail_open ? -1 : 0;
}

static int t_exists(void)
{
	note("exists");
	if (!file_set)
		return 0;
	return 1;
}

static int t_size(int *out)
{
	note("size");
	if (!file_set)
		return -1;
	*out = (int)strlen(file);
	return 0;
}

static int t_read(void *buf, int len, int *nread)
{
	int n;

	note("read");
	if (!file_set)
		return -1;
	n = (int)strlen(file);
	if (n > len)
		n = len;
	memcpy(buf, file, (size_t)n);
	*nread = n;
	return 0;
}

static int t_unlink(void)
{
	note("unlink");
	if (fail_unlink)
		return -1;
	if (!exists_after_unlink)
		file_set = 0;
	return 0;
}

static const struct maskrom_fs ops = {
	.open_volume = t_open,
	.exists = t_exists,
	.size = t_size,
	.read = t_read,
	.unlink = t_unlink,
	.magic = ZLYME_MASKROM_MAGIC,
	.magic_len = sizeof(ZLYME_MASKROM_MAGIC) - 1,
};

static int expect(const char *name, int got, int want, const char *trace)
{
	if (got == want)
		return 0;
	fprintf(stderr, "%s: got %d want %d trace '%s'\n", name, got, want, trace);
	return 1;
}

static void reset_fs(const char *contents)
{
	fail_open = 0;
	fail_unlink = 0;
	exists_after_unlink = 0;
	logbuf[0] = '\0';
	if (!contents) {
		file_set = 0;
		file[0] = '\0';
		return;
	}
	file_set = 1;
	snprintf(file, sizeof(file), "%s", contents);
}

int main(void)
{
	int rc;
	int bad = 0;

	reset_fs(NULL);
	rc = maskrom_request_consume(&ops);
	bad |= expect("absent", rc, MASKROM_BOOT, logbuf);
	if (strstr(logbuf, "unlink") || strstr(logbuf, "rbrom"))
		bad |= expect("absent-no-unlink", 1, 0, logbuf);

	reset_fs("");
	rc = maskrom_request_consume(&ops);
	bad |= expect("empty", rc, MASKROM_REJECT, logbuf);
	if (strstr(logbuf, "unlink"))
		bad |= expect("empty-kept", 1, 0, logbuf);
	if (!file_set)
		bad |= expect("empty-still-there", 0, 1, logbuf);

	reset_fs("not-the-magic");
	rc = maskrom_request_consume(&ops);
	bad |= expect("corrupt", rc, MASKROM_REJECT, logbuf);
	if (!file_set || strcmp(file, "not-the-magic") != 0)
		bad |= expect("corrupt-kept", 1, 0, logbuf);

	reset_fs(ZLYME_MASKROM_MAGIC "\n");
	rc = maskrom_request_consume(&ops);
	bad |= expect("newline", rc, MASKROM_REJECT, logbuf);

	fail_unlink = 1;
	reset_fs(ZLYME_MASKROM_MAGIC);
	fail_unlink = 1;
	rc = maskrom_request_consume(&ops);
	bad |= expect("unlink-fail", rc, MASKROM_REJECT, logbuf);
	if (!file_set)
		bad |= expect("unlink-fail-kept", 0, 1, logbuf);

	reset_fs(ZLYME_MASKROM_MAGIC);
	exists_after_unlink = 1;
	rc = maskrom_request_consume(&ops);
	bad |= expect("still-there", rc, MASKROM_REJECT, logbuf);

	reset_fs(ZLYME_MASKROM_MAGIC);
	rc = maskrom_request_consume(&ops);
	bad |= expect("enter", rc, MASKROM_ENTER, logbuf);
	if (file_set)
		bad |= expect("enter-gone", 1, 0, logbuf);
	else if (rc == MASKROM_ENTER)
		rbroms++;
	if (!strstr(logbuf, "unlink") || strstr(logbuf, "unlink") > strstr(logbuf, "exists")) {
		/* unlink must happen, and a later exists is in the trace after it */
	}
	if (!strstr(logbuf, "unlink"))
		bad |= expect("enter-unlinked", 1, 0, logbuf);
	{
		const char *u = strstr(logbuf, "unlink");
		const char *e = u ? strstr(u + 6, "exists") : NULL;

		if (!e)
			bad |= expect("exists-after-unlink", 1, 0, logbuf);
	}

	logbuf[0] = '\0';
	rc = maskrom_request_consume(&ops);
	bad |= expect("second", rc, MASKROM_BOOT, logbuf);
	if (strstr(logbuf, "unlink"))
		bad |= expect("second-no-unlink", 1, 0, logbuf);

	reset_fs(ZLYME_MASKROM_MAGIC);
	fail_open = 1;
	rc = maskrom_request_consume(&ops);
	bad |= expect("no-volume", rc, MASKROM_BOOT, logbuf);

	if (rbroms != 1)
		bad |= expect("rbrom-once", rbroms, 1, logbuf);

	if (bad)
		return 1;
	puts("maskrom-request-test: ok");
	return 0;
}
