/* Request the kernel restart command "maskrom".
 * No physical addresses and no NAND writes. A successful request
 * does not return: Linux leaves.
 */
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/reboot.h>

int main(int argc, char **argv)
{
	long rc;

	(void)argv;
	if (argc != 1) {
		fprintf(stderr, "zlyme-maskrom: no arguments\n");
		return 2;
	}

	sync();
	rc = syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		     LINUX_REBOOT_CMD_RESTART2, "maskrom");
	if (rc != 0) {
		perror("zlyme-maskrom");
		return 1;
	}
	fprintf(stderr, "zlyme-maskrom: restart returned\n");
	return 1;
}
