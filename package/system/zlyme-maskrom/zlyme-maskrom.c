/* Queue one MASKROM boot on ZLYMEBOOT, then use an ordinary restart.
 * The file is ZLYME-MASKROM-1 at /boot/zlyme-maskrom.request. U-Boot
 * deletes that file before it runs rbrom. This process does not touch
 * NAND and does not pass a restart command string.
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>
#include <linux/limits.h>
#include <linux/reboot.h>

#define ZLYME_MASKROM_MAGIC "ZLYME-MASKROM-1"

static const char *boot_dir(void)
{
	const char *boot;

	if (getenv("ZLYME_MASKROM_TEST")) {
		boot = getenv("ZLYME_BOOT");
		if (boot && boot[0])
			return boot;
	}
	return "/boot";
}

static int read_exact(const char *path)
{
	char buf[64];
	ssize_t n;
	int fd;
	size_t len = sizeof(ZLYME_MASKROM_MAGIC) - 1;

	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	n = read(fd, buf, sizeof(buf));
	if (close(fd) != 0)
		return -1;
	if (n != (ssize_t)len || memcmp(buf, ZLYME_MASKROM_MAGIC, len) != 0)
		return -1;
	return 0;
}

static int write_exact(const char *boot)
{
	char tmp[PATH_MAX];
	char final[PATH_MAX];
	char buf[64];
	ssize_t n;
	int fd;
	int dfd;
	size_t len = sizeof(ZLYME_MASKROM_MAGIC) - 1;

	if (snprintf(tmp, sizeof(tmp), "%s/.zlyme-maskrom.request.tmp", boot)
	    >= (int)sizeof(tmp))
		return -1;
	if (snprintf(final, sizeof(final), "%s/zlyme-maskrom.request", boot)
	    >= (int)sizeof(final))
		return -1;

	unlink(tmp);
	fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
	if (fd < 0)
		return -1;
	n = write(fd, ZLYME_MASKROM_MAGIC, len);
	if (n != (ssize_t)len || fsync(fd) != 0) {
		close(fd);
		unlink(tmp);
		return -1;
	}
	if (close(fd) != 0) {
		unlink(tmp);
		return -1;
	}
	if (rename(tmp, final) != 0) {
		unlink(tmp);
		return -1;
	}
	dfd = open(boot, O_RDONLY | O_DIRECTORY);
	if (dfd >= 0) {
		(void)fsync(dfd);
		close(dfd);
	}
	fd = open(final, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	n = read(fd, buf, sizeof(buf));
	if (close(fd) != 0)
		return -1;
	if (n != (ssize_t)len || memcmp(buf, ZLYME_MASKROM_MAGIC, len) != 0)
		return -1;
	return 0;
}

static void note_reboot(void)
{
	const char *log;
	FILE *f;

	log = getenv("ZLYME_MASKROM_LOG");
	if (!log)
		return;
	f = fopen(log, "a");
	if (!f)
		return;
	fputs("ordinary-reboot\n", f);
	fclose(f);
}

int main(int argc, char **argv)
{
	const char *writer = "/usr/sbin/zlyme-boot-write";
	const char *self = "/usr/sbin/zlyme-maskrom";
	const char *boot;
	pid_t pid;
	int status;
	long rc;

	if (argc == 2 && strcmp(argv[1], "--write") == 0)
		return write_exact(boot_dir()) == 0 ? 0 : 1;
	if (argc != 1) {
		fprintf(stderr, "zlyme-maskrom: no arguments\n");
		return 2;
	}

	if (getenv("ZLYME_MASKROM_TEST")) {
		if (getenv("ZLYME_BOOT_WRITE"))
			writer = getenv("ZLYME_BOOT_WRITE");
		self = argv[0];
	}

	boot = boot_dir();
	pid = fork();
	if (pid < 0) {
		fprintf(stderr, "zlyme-maskrom: the request was not written\n");
		return 1;
	}
	if (pid == 0) {
		execl(writer, writer, self, "--write", (char *)NULL);
		_exit(127);
	}
	if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) ||
	    WEXITSTATUS(status) != 0) {
		fprintf(stderr, "zlyme-maskrom: the request was not written\n");
		return 1;
	}
	{
		char path[PATH_MAX];

		if (snprintf(path, sizeof(path), "%s/zlyme-maskrom.request", boot)
		    >= (int)sizeof(path) || read_exact(path) != 0) {
			fprintf(stderr, "zlyme-maskrom: the request did not verify\n");
			return 1;
		}
	}

	sync();
	if (getenv("ZLYME_MASKROM_TEST")) {
		/* Test-only. Production always uses the reboot below. */
		if (getenv("ZLYME_MASKROM_REBOOT_FAIL")) {
			fprintf(stderr, "zlyme-maskrom: reboot failed; MASKROM is queued for the next boot\n");
			return 1;
		}
		note_reboot();
		return 0;
	}

	rc = syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		     LINUX_REBOOT_CMD_RESTART, NULL);
	if (rc != 0) {
		fprintf(stderr, "zlyme-maskrom: reboot failed; MASKROM is queued for the next boot\n");
		return 1;
	}
	fprintf(stderr, "zlyme-maskrom: reboot returned; MASKROM is queued for the next boot\n");
	return 1;
}
