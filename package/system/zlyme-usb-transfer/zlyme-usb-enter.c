/*
 * Enter a private mount namespace and exec uMTP there.
 *
 * uMTP-Responder 1.8.1 follows symlinks (stat64 and open). Its unreleased
 * realpath check compares a string prefix and is not race-safe. This process
 * makes the mount tree private, bind-mounts only the export directories, and
 * pivot_roots onto that tree before exec. A symlink, including one replaced
 * during a transfer, can only name a path that is still mounted here.
 *
 * The kernel already has mount namespaces. This is not a new subsystem and
 * it does not enable Landlock. The binary is not a boot service.
 */
#define _GNU_SOURCE

#include <elf.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/limits.h>
#include <linux/mount.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAX_EXPORTS 16
#define MAX_BINDS 64

static char jail[PATH_MAX];
static char exports_copy[MAX_EXPORTS][PATH_MAX];
static int export_count;
static char binds[MAX_BINDS][PATH_MAX];
static int bind_count;

static void die_errno(const char *what)
{
	dprintf(STDERR_FILENO, "zlyme-usb-enter: %s: %s\n", what, strerror(errno));
	_exit(1);
}

static void die_msg(const char *what)
{
	dprintf(STDERR_FILENO, "zlyme-usb-enter: %s\n", what);
	_exit(1);
}

static int component_is(const char *path, const char *name)
{
	size_t nlen = strlen(name);
	const char *p = path;

	while ((p = strstr(p, name)) != NULL) {
		if ((p == path || p[-1] == '/') &&
		    (p[nlen] == '/' || p[nlen] == '\0'))
			return 1;
		p += nlen;
	}
	return 0;
}

static int path_forbidden(const char *path)
{
	if (strcmp(path, "/dev") == 0 || strncmp(path, "/dev/", 5) == 0)
		return 1;
	if (strcmp(path, "/sys") == 0 || strncmp(path, "/sys/", 5) == 0)
		return 1;
	if (strcmp(path, "/proc") == 0 || strncmp(path, "/proc/", 6) == 0)
		return 1;
	if (strcmp(path, "/boot") == 0 || strncmp(path, "/boot/", 6) == 0)
		return 1;
	if (component_is(path, ".config") || component_is(path, ".update") ||
	    component_is(path, ".logs"))
		return 1;
	return 0;
}

static int path_has_dotdot(const char *path)
{
	const char *p;

	if (path[0] != '/')
		return 1;
	for (p = path; *p; p++) {
		if (p[0] == '/' && p[1] == '.' && p[2] == '.' &&
		    (p[3] == '/' || p[3] == '\0'))
			return 1;
		if (p[0] == '/' && p[1] == '/' )
			return 1;
	}
	return 0;
}

static void mkdir_p(const char *path)
{
	char buf[PATH_MAX];
	size_t len;
	size_t i;

	len = strlen(path);
	if (len == 0 || len >= sizeof(buf))
		die_msg("path does not fit");
	memcpy(buf, path, len + 1);
	for (i = 1; i < len; i++) {
		if (buf[i] != '/')
			continue;
		buf[i] = '\0';
		if (mkdir(buf, 0755) != 0 && errno != EEXIST)
			die_errno(buf);
		buf[i] = '/';
	}
	if (mkdir(buf, 0755) != 0 && errno != EEXIST)
		die_errno(buf);
}

static int open_tree_fd(int dfd)
{
	return (int)syscall(SYS_open_tree, dfd, "",
			    AT_EMPTY_PATH | OPEN_TREE_CLONE | OPEN_TREE_CLOEXEC);
}

static void move_onto(int fd, const char *dest)
{
	if (syscall(SYS_move_mount, fd, "", AT_FDCWD, dest,
		    MOVE_MOUNT_F_EMPTY_PATH) != 0)
		die_errno(dest);
}

/* Walk without following a symlink, then clone that directory only.
 * restricted exports cannot name private OS paths. The FunctionFS
 * mount and /dev/mqueue are explicit exceptions.
 */
static void bind_directory(const char *src, int restricted)
{
	int dfd;
	int next;
	int tree;
	char dest[PATH_MAX];
	const char *p;
	char comp[NAME_MAX + 1];
	size_t n;

	if (path_has_dotdot(src) || (restricted && path_forbidden(src)))
		die_msg("refusing export path");
	dfd = open("/", O_PATH | O_DIRECTORY | O_CLOEXEC);
	if (dfd < 0)
		die_errno("/");
	p = src;
	while (*p == '/')
		p++;
	while (*p) {
		n = 0;
		while (p[n] && p[n] != '/') {
			if (n >= NAME_MAX)
				die_msg("export component is too long");
			comp[n] = p[n];
			n++;
		}
		comp[n] = '\0';
		if (n == 0 || strcmp(comp, ".") == 0 || strcmp(comp, "..") == 0)
			die_msg("refusing export component");
		next = openat(dfd, comp, O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
		if (next < 0) {
			struct stat st;

			/* O_PATH|O_NOFOLLOW on a symlink returns the link and
			 * O_DIRECTORY then fails with ENOTDIR. ELOOP is the
			 * same refusal on older kernels. Do not follow it.
			 */
			if ((errno == ENOTDIR || errno == ELOOP) &&
			    fstatat(dfd, comp, &st, AT_SYMLINK_NOFOLLOW) == 0 &&
			    S_ISLNK(st.st_mode))
				die_msg("refusing export symlink");
			die_errno(src);
		}
		close(dfd);
		dfd = next;
		p += n;
		while (*p == '/')
			p++;
	}
	tree = open_tree_fd(dfd);
	close(dfd);
	if (tree < 0)
		die_errno(src);
	if ((size_t)snprintf(dest, sizeof(dest), "%s%s", jail, src) >= sizeof(dest))
		die_msg("jail path does not fit");
	mkdir_p(dest);
	move_onto(tree, dest);
	close(tree);
}

static void bind_file_at(const char *src)
{
	char dest[PATH_MAX];
	int fd;
	struct stat st;

	if (path_has_dotdot(src))
		die_msg("refusing file path");
	if ((size_t)snprintf(dest, sizeof(dest), "%s%s", jail, src) >= sizeof(dest))
		die_msg("jail path does not fit");
	mkdir_p(dest);
	/* mkdir_p created dest as a directory. Replace it with a file mountpoint. */
	if (rmdir(dest) != 0 && errno != ENOENT && errno != ENOTDIR)
		die_errno(dest);
	fd = open(dest, O_CREAT | O_WRONLY | O_CLOEXEC, 0644);
	if (fd < 0) {
		/* Parent mkdir_p left dest as the last directory. Recreate the parent only. */
		die_errno(dest);
	}
	close(fd);
	if (lstat(src, &st) != 0)
		die_errno(src);
	/* mount follows a trusted symlink and attaches that inode here. */
	if (mount(src, dest, NULL, MS_BIND, NULL) != 0)
		die_errno(src);
}

static int already_bound(const char *path)
{
	int i;

	for (i = 0; i < bind_count; i++) {
		if (strcmp(binds[i], path) == 0)
			return 1;
	}
	return 0;
}

static void remember_and_bind(const char *path)
{
	if (path[0] != '/')
		return;
	if (already_bound(path))
		return;
	if (bind_count >= MAX_BINDS)
		die_msg("too many files to bind into the jail");
	if ((size_t)snprintf(binds[bind_count], PATH_MAX, "%s", path) >= PATH_MAX)
		die_msg("bind path does not fit");
	bind_count++;
	bind_file_at(path);
}

static void interpreter_of(const char *path, char *interp, size_t interp_len)
{
	int fd;
	Elf64_Ehdr eh;
	Elf64_Phdr ph;
	unsigned int i;
	ssize_t n;

	interp[0] = '\0';
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		die_errno(path);
	n = read(fd, &eh, sizeof(eh));
	if (n != (ssize_t)sizeof(eh))
		die_msg("short ELF header");
	if (memcmp(eh.e_ident, ELFMAG, SELFMAG) != 0) {
		close(fd);
		return;
	}
	if (eh.e_ident[EI_CLASS] != ELFCLASS64 || eh.e_ident[EI_DATA] != ELFDATA2LSB)
		die_msg("unexpected ELF class");
	for (i = 0; i < eh.e_phnum; i++) {
		if (lseek(fd, (off_t)(eh.e_phoff + (i * eh.e_phentsize)), SEEK_SET) < 0)
			die_errno(path);
		if (read(fd, &ph, sizeof(ph)) != (ssize_t)sizeof(ph))
			die_msg("short program header");
		if (ph.p_type != PT_INTERP)
			continue;
		if (ph.p_filesz == 0 || ph.p_filesz >= interp_len)
			die_msg("interpreter path does not fit");
		if (lseek(fd, (off_t)ph.p_offset, SEEK_SET) < 0)
			die_errno(path);
		if (read(fd, interp, ph.p_filesz) != (ssize_t)ph.p_filesz)
			die_msg("short interpreter path");
		interp[ph.p_filesz - 1] = '\0';
		break;
	}
	close(fd);
}

static void bind_loader_list(const char *interp, const char *prog)
{
	int pipes[2];
	pid_t pid;
	FILE *in;
	char line[PATH_MAX * 2];
	int status;

	if (pipe(pipes) != 0)
		die_errno("pipe");
	pid = fork();
	if (pid < 0)
		die_errno("fork");
	if (pid == 0) {
		close(pipes[0]);
		if (dup2(pipes[1], STDOUT_FILENO) < 0)
			_exit(127);
		close(pipes[1]);
		execl(interp, interp, "--list", prog, (char *)NULL);
		_exit(127);
	}
	close(pipes[1]);
	in = fdopen(pipes[0], "r");
	if (in == NULL)
		die_errno("fdopen");
	while (fgets(line, sizeof(line), in) != NULL) {
		char *arrow;
		char *start;
		char *end;

		arrow = strstr(line, "=>");
		if (arrow != NULL) {
			start = arrow + 2;
			while (*start == ' ' || *start == '\t')
				start++;
		} else {
			start = line;
			while (*start == ' ' || *start == '\t')
				start++;
		}
		if (*start != '/')
			continue;
		end = start;
		while (*end && *end != ' ' && *end != '\n' && *end != '\t')
			end++;
		*end = '\0';
		remember_and_bind(start);
	}
	fclose(in);
	if (waitpid(pid, &status, 0) < 0)
		die_errno("waitpid");
	if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
		die_msg("dynamic linker did not list dependencies");
}

static void bind_program(const char *path, int depth);

static void bind_script(const char *path)
{
	int fd;
	char buf[256];
	ssize_t n;
	char *interp;
	char *end;
	char saved;

	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		die_errno(path);
	n = read(fd, buf, sizeof(buf) - 1);
	close(fd);
	if (n < 2)
		die_msg("short script");
	buf[n] = '\0';
	if (buf[0] != '#' || buf[1] != '!')
		die_msg("program is not an ELF binary or a script");
	interp = buf + 2;
	while (*interp == ' ' || *interp == '\t')
		interp++;
	end = interp;
	while (*end && *end != ' ' && *end != '\t' && *end != '\n')
		end++;
	saved = *end;
	*end = '\0';
	(void)saved;
	if (interp[0] != '/')
		die_msg("script interpreter is not absolute");
	remember_and_bind(path);
	bind_program(interp, 1);
}

static void bind_program(const char *path, int depth)
{
	char interp[PATH_MAX];
	unsigned char mag[4];
	int fd;
	ssize_t n;

	if (depth > 4)
		die_msg("interpreter chain is too deep");
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		die_errno(path);
	n = read(fd, mag, sizeof(mag));
	close(fd);
	if (n < 2)
		die_msg("short program");
	if (mag[0] == 0x7f && mag[1] == 'E' && mag[2] == 'L' && mag[3] == 'F') {
		remember_and_bind(path);
		interpreter_of(path, interp, sizeof(interp));
		if (interp[0] == '\0')
			return;
		remember_and_bind(interp);
		bind_loader_list(interp, path);
		return;
	}
	if (mag[0] == '#' && mag[1] == '!') {
		if (depth != 0)
			die_msg("nested script interpreter is not supported");
		bind_script(path);
		return;
	}
	die_msg("program is not an ELF binary or a script");
}

static void load_exports(const char *file)
{
	FILE *in;
	char line[PATH_MAX];

	in = fopen(file, "r");
	if (in == NULL)
		die_errno(file);
	while (fgets(line, sizeof(line), in) != NULL) {
		char *tab;
		size_t len;

		if (line[0] == '\0' || line[0] == '\n')
			continue;
		tab = strchr(line, '\t');
		if (tab != NULL)
			*tab = '\0';
		len = strlen(line);
		while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
			line[len - 1] = '\0';
			len--;
		}
		if (len == 0)
			continue;
		if (export_count >= MAX_EXPORTS)
			die_msg("too many exports");
		if (len >= PATH_MAX)
			die_msg("export path does not fit");
		memcpy(exports_copy[export_count], line, len + 1);
		export_count++;
	}
	fclose(in);
	if (export_count == 0)
		die_msg("no exports to confine");
}

static void require_absent(const char *path)
{
	if (access(path, F_OK) == 0) {
		dprintf(STDERR_FILENO, "zlyme-usb-enter: jail still exposes %s\n", path);
		_exit(1);
	}
}

int main(int argc, char **argv)
{
	const char *run;
	const char *ffs;
	const char *prog;
	char conf[PATH_MAX];
	char expfile[PATH_MAX];
	int ns;
	int i;
	struct stat st;

	(void)argc;
	(void)argv;
	run = getenv("ZLYME_USB_RUN");
	ffs = getenv("ZLYME_USB_FFS");
	prog = getenv("ZLYME_USB_UMTPRD");
	if (run == NULL || run[0] != '/' || ffs == NULL || ffs[0] != '/' ||
	    prog == NULL || prog[0] != '/')
		die_msg("missing jail paths");
	if ((size_t)snprintf(conf, sizeof(conf), "%s/umtprd.conf", run) >= sizeof(conf) ||
	    (size_t)snprintf(expfile, sizeof(expfile), "%s/exports", run) >= sizeof(expfile) ||
	    (size_t)snprintf(jail, sizeof(jail), "%s/jail", run) >= sizeof(jail))
		die_msg("jail path does not fit");
	load_exports(expfile);

	ns = open("/proc/self/ns/mnt", O_RDONLY | O_CLOEXEC);
	if (ns < 0)
		die_errno("open mount namespace");
	if (unshare(CLONE_NEWNS) != 0)
		die_errno("unshare mount namespace");
	{
		int now;
		struct stat before_st;
		struct stat after_st;

		now = open("/proc/self/ns/mnt", O_RDONLY | O_CLOEXEC);
		if (now < 0)
			die_errno("open new mount namespace");
		if (fstat(ns, &before_st) != 0 || fstat(now, &after_st) != 0)
			die_errno("stat mount namespace");
		close(ns);
		close(now);
		if (before_st.st_dev == after_st.st_dev &&
		    before_st.st_ino == after_st.st_ino)
			die_msg("refusing to pivot the caller's mount namespace");
	}
	if (mount(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL) != 0)
		die_errno("make mount tree private");
	if (lstat(jail, &st) != 0) {
		if (mkdir(jail, 0755) != 0)
			die_errno(jail);
	} else if (S_ISLNK(st.st_mode) || !S_ISDIR(st.st_mode)) {
		die_msg("jail path is not a directory");
	}
	if (mount("tmpfs", jail, "tmpfs", MS_NOSUID | MS_NODEV, "mode=755") != 0)
		die_errno("jail tmpfs");

	for (i = 0; i < export_count; i++)
		bind_directory(exports_copy[i], 1);
	remember_and_bind(conf);
	bind_directory(ffs, 0);
	if (lstat("/dev/mqueue", &st) == 0 && S_ISDIR(st.st_mode) && !S_ISLNK(st.st_mode))
		bind_directory("/dev/mqueue", 0);
	bind_program(prog, 0);

	if (chdir(jail) != 0)
		die_errno(jail);
	if (mkdir("oldroot", 0755) != 0 && errno != EEXIST)
		die_errno("oldroot");
	if (syscall(SYS_pivot_root, ".", "oldroot") != 0)
		die_errno("pivot_root");
	if (umount2("oldroot", MNT_DETACH) != 0)
		die_errno("umount old root");
	require_absent("oldroot/etc");
	require_absent("oldroot/storage");
	require_absent("oldroot/boot");
	require_absent("/etc");
	require_absent("/boot");
	require_absent("/proc/1");
	require_absent("/root");
	require_absent("/dev/mmcblk0");
	require_absent("/storage/.config");
	require_absent("/storage/.update");
	if (rmdir("oldroot") != 0)
		die_errno("remove oldroot");

	execl(prog, prog, "-conf", conf, (char *)NULL);
	die_errno(prog);
}
