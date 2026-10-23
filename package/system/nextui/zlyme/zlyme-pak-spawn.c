/*
 * Run one pak in a new session and do not exit while that session
 * still has a process.
 *
 * BusyBox setsid returns success from its parent without waiting when
 * setsid() fails, and the shell's wait then returns while the real
 * session keeps running. A leader can also exit while a member stays
 * in the session: Abombniball was reparented to init, still in the
 * dead leader's session, and still holding DRM after wait status 0.
 * This process is the one nextui-session waits on. It is not in the
 * pak session, so it can signal that session without signaling the
 * frontend.
 *
 * argv: <leader-file> <command> [args...]
 * The leader file is written only after the child has called setsid().
 */
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <dirent.h>
#include <unistd.h>

#define TERM_POLLS 30
#define KILL_POLLS 10
#define POLL_US 50000
#define CLEANUP_FAILED 125

static volatile sig_atomic_t stop_requested;
static pid_t child_pid;

struct proc_info {
	pid_t pid;
	pid_t pgid;
	pid_t sid;
	char state;
	unsigned long long starttime;
};

struct member_list {
	struct proc_info *items;
	size_t count;
	size_t capacity;
};

struct leader_identity {
	char ok;
	unsigned long long starttime;
};

static void on_term(int sig)
{
	(void)sig;
	stop_requested = 1;
}

static const char *proc_root(void)
{
#ifdef ZLYME_TESTING
	const char *root = getenv("ZLYME_TEST_PROC_ROOT");

	if (root && root[0] != '\0')
		return root;
#endif
	return "/proc";
}

static int parse_number(const char *text, long *value)
{
	char *end;
	long parsed;

	errno = 0;
	parsed = strtol(text, &end, 10);
	if (errno != 0 || end == text || *end != '\0')
		return -1;
	*value = parsed;
	return 0;
}

static int parse_starttime(const char *text, unsigned long long *value)
{
	char *end;
	unsigned long long parsed;

	errno = 0;
	parsed = strtoull(text, &end, 10);
	if (errno != 0 || end == text || *end != '\0')
		return -1;
	*value = parsed;
	return 0;
}

static int parse_info(char *line, pid_t pid, struct proc_info *info)
{
	char *rest;
	char *save = NULL;
	char *token;
	long value;
	int field = 0;

	rest = strrchr(line, ')');
	if (!rest || rest[1] == '\0')
		return -1;
	memset(info, 0, sizeof *info);
	info->pid = pid;
	for (token = strtok_r(rest + 1, " \t\r\n", &save);
	     token;
	     token = strtok_r(NULL, " \t\r\n", &save), field++) {
		switch (field) {
		case 0:
			if (token[0] == '\0' || token[1] != '\0')
				return -1;
			info->state = token[0];
			break;
		case 2:
			if (parse_number(token, &value) != 0)
				return -1;
			info->pgid = (pid_t)value;
			break;
		case 3:
			if (parse_number(token, &value) != 0)
				return -1;
			info->sid = (pid_t)value;
			break;
		case 19:
			if (parse_starttime(token, &info->starttime) != 0)
				return -1;
			return 0;
		default:
			break;
		}
	}
	return -1;
}

/* 1 is a process, 0 means it disappeared, -1 is an inspection error. */
static int read_info_at(const char *root, pid_t pid, struct proc_info *info)
{
	char path[4096];
	char buf[4096];
	ssize_t n;
	int fd, saved;

	if (pid <= 0)
		return -1;
	if (snprintf(path, sizeof path, "%s/%d/stat", root, (int)pid) >=
	    (int)sizeof path)
		return -1;
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0) {
		if (errno == ENOENT || errno == ESRCH)
			return 0;
		return -1;
	}
	n = read(fd, buf, sizeof buf - 1);
	saved = errno;
	close(fd);
	errno = saved;
	if (n < 0 && (errno == ENOENT || errno == ESRCH))
		return 0;
	if (n <= 0)
		return -1;
	buf[n] = '\0';
	return parse_info(buf, pid, info) == 0 ? 1 : -1;
}

static int read_info(pid_t pid, struct proc_info *info)
{
	return read_info_at(proc_root(), pid, info);
}

static int own_session(pid_t leader)
{
	pid_t ours;

	if (leader <= 1)
		return 1;
	ours = getsid(0);
	if (ours > 0 && (leader == ours || leader == getpgrp()))
		return 1;
	return 0;
}

static void free_members(struct member_list *list)
{
	free(list->items);
	memset(list, 0, sizeof *list);
}

static int append_member(struct member_list *list, const struct proc_info *info)
{
	struct proc_info *items;
	size_t capacity;

	if (list->count == list->capacity) {
		capacity = list->capacity ? list->capacity * 2 : 16;
		if (capacity < list->capacity ||
		    capacity > SIZE_MAX / sizeof *list->items)
			return -1;
		items = realloc(list->items, capacity * sizeof *items);
		if (!items)
			return -1;
		list->items = items;
		list->capacity = capacity;
	}
	list->items[list->count++] = *info;
	return 0;
}

/* 0 is a complete scan. Any negative result is unsafe to treat as empty. */
static int leader_identity_ok(pid_t leader, unsigned long long starttime)
{
	struct proc_info info;
	int rc;

	rc = read_info(leader, &info);
	if (rc <= 0)
		return rc;
	if (info.starttime != starttime || info.pgid != leader ||
	    info.sid != leader || info.state == 'Z')
		return -1;
	return 1;
}

static int collect_members(pid_t leader, unsigned long long starttime,
			   struct member_list *list)
{
	DIR *dir;
	struct dirent *ent;
	int scan_error = 0;

	memset(list, 0, sizeof *list);
	if (own_session(leader))
		return -1;
	if (leader_identity_ok(leader, starttime) < 0)
		return -1;
	dir = opendir(proc_root());
	if (!dir)
		return -1;
	for (;;) {
		struct proc_info info;
		pid_t pid;
		char *end;
		int rc;

		errno = 0;
		ent = readdir(dir);
		if (!ent) {
			if (errno != 0)
				scan_error = 1;
			break;
		}
		if (ent->d_name[0] < '1' || ent->d_name[0] > '9')
			continue;
		pid = (pid_t)strtol(ent->d_name, &end, 10);
		if (*end != '\0' || pid <= 1 || pid == getpid() || pid == leader)
			continue;
		rc = read_info(pid, &info);
		if (rc == 0)
			continue;
		if (rc < 0) {
			scan_error = 1;
			break;
		}
		if (info.sid != leader || info.state == 'Z')
			continue;
		if (append_member(list, &info) != 0) {
			scan_error = 1;
			break;
		}
	}
	if (closedir(dir) != 0)
		scan_error = 1;
	if (!scan_error && leader_identity_ok(leader, starttime) < 0)
		scan_error = 1;
	if (scan_error) {
		free_members(list);
		return -1;
	}
	return 0;
}

static int session_busy(pid_t leader, unsigned long long starttime)
{
	struct member_list list;
	int rc;

	rc = collect_members(leader, starttime, &list);
	if (rc != 0)
		return -1;
	rc = list.count > 0;
	free_members(&list);
	return rc;
}

static int same_process(const struct proc_info *a, const struct proc_info *b)
{
	return a->pid == b->pid && a->pgid == b->pgid &&
	       a->sid == b->sid && a->starttime == b->starttime &&
	       b->state != 'Z';
}

static int signal_verified(const struct proc_info *expected, int sig)
{
	struct proc_info current;
	int rc;

	rc = read_info(expected->pid, &current);
	if (rc == 0)
		return 0;
	if (rc < 0)
		return -1;
	if (!same_process(expected, &current))
		return 0;
#if defined(SYS_pidfd_open) && defined(SYS_pidfd_send_signal)
	{
		int pidfd = (int)syscall(SYS_pidfd_open, expected->pid, 0);

		if (pidfd >= 0) {
			rc = read_info(expected->pid, &current);
			if (rc <= 0 || !same_process(expected, &current)) {
				close(pidfd);
				return rc < 0 ? -1 : 0;
			}
			rc = (int)syscall(SYS_pidfd_send_signal, pidfd, sig, NULL, 0);
			if (rc < 0 && errno == ESRCH)
				rc = 0;
			else if (rc == 0)
				rc = 1;
			close(pidfd);
			return rc;
		}
		return errno == ESRCH ? 0 : -1;
	}
#else
	/*
	 * A read of starttime followed by kill(pid) has a PID-reuse race.
	 * This target provides pidfds; fail closed on a build whose headers
	 * cannot express the safe operation.
	 */
	(void)sig;
	return -1;
#endif
}

static int signal_session(pid_t leader, unsigned long long starttime, int sig)
{
	struct member_list list;
	struct proc_info leader_info;
	size_t i;
	int rc, failed = 0;

	if (own_session(leader))
		return -1;
	rc = read_info(leader, &leader_info);
	if (rc < 0)
		return -1;
	if (rc > 0) {
		if (leader_info.starttime != starttime ||
		    leader_info.pgid != leader || leader_info.sid != leader ||
		    leader_info.state == 'Z')
			return -1;
		rc = signal_verified(&leader_info, sig);
		if (rc < 0)
			failed = 1;
	}
	if (collect_members(leader, starttime, &list) != 0)
		return -1;
	for (i = 0; i < list.count; i++) {
		rc = signal_verified(&list.items[i], sig);
		if (rc < 0)
			failed = 1;
	}
	free_members(&list);
	return failed ? -1 : 0;
}

static int reap_session(pid_t leader, unsigned long long starttime)
{
	int i, busy;

	/* An empty session is not a target. kill(-pgid) on a reused id
	 * would hit a different group. */
	busy = session_busy(leader, starttime);
	if (busy < 0)
		return -1;
	if (!busy)
		return 0;
	if (signal_session(leader, starttime, SIGTERM) != 0)
		return -1;
	for (i = 0; i < TERM_POLLS; i++) {
		busy = session_busy(leader, starttime);
		if (busy < 0)
			return -1;
		if (!busy)
			return 0;
		usleep(POLL_US);
	}
	if (signal_session(leader, starttime, SIGKILL) != 0)
		return -1;
	for (i = 0; i < KILL_POLLS; i++) {
		busy = session_busy(leader, starttime);
		if (busy < 0)
			return -1;
		if (!busy)
			return 0;
		usleep(POLL_US);
	}
	return -1;
}

static int write_leader(const char *path, pid_t pid)
{
	char tmp[4096];
	char body[32];
	int fd, n, nw;

	n = snprintf(tmp, sizeof tmp, "%s.tmp", path);
	if (n < 0 || (size_t)n >= sizeof tmp)
		return -1;
	fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
	if (fd < 0)
		return -1;
	nw = snprintf(body, sizeof body, "%d\n", (int)pid);
	if (nw < 0 || write(fd, body, (size_t)nw) != nw) {
		close(fd);
		unlink(tmp);
		return -1;
	}
	if (close(fd) != 0) {
		unlink(tmp);
		return -1;
	}
	if (rename(tmp, path) != 0) {
		unlink(tmp);
		return -1;
	}
	return 0;
}

static int child_status(int st)
{
	if (WIFEXITED(st)) {
		int rc = WEXITSTATUS(st);

		/*
		 * 125 is the ownership-failure contract with nextui-session.
		 * Do not let a pak's own exit code masquerade as unresolved
		 * cleanup and permanently suppress the frontend.
		 */
		return rc == CLEANUP_FAILED ? 126 : rc;
	}
	if (WIFSIGNALED(st))
		return 128 + WTERMSIG(st);
	return 1;
}

int main(int argc, char **argv)
{
	int fds[2];
	int st = 0;
	struct leader_identity identity;
	struct sigaction sa;

	if (argc < 3 || argv[1][0] == '\0')
		return 2;

	memset(&sa, 0, sizeof sa);
	sa.sa_handler = on_term;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGTERM, &sa, NULL);

	if (pipe2(fds, O_CLOEXEC) != 0)
		return 127;
	child_pid = fork();
	if (child_pid < 0)
		return 127;
	if (child_pid == 0) {
		struct proc_info self;

		close(fds[0]);
		if (setsid() < 0)
			_exit(127);
		memset(&identity, 0, sizeof identity);
		if (read_info_at("/proc", getpid(), &self) != 1)
			_exit(127);
		identity.ok = 1;
		identity.starttime = self.starttime;
		if (write(fds[1], &identity, sizeof identity) !=
		    (ssize_t)sizeof identity)
			_exit(127);
		close(fds[1]);
		execvp(argv[2], &argv[2]);
		_exit(127);
	}
	close(fds[1]);
	memset(&identity, 0, sizeof identity);
	if (read(fds[0], &identity, sizeof identity) !=
	    (ssize_t)sizeof identity || identity.ok != 1 ||
	    identity.starttime == 0) {
		close(fds[0]);
		waitpid(child_pid, &st, 0);
		return 127;
	}
	close(fds[0]);
	if (write_leader(argv[1], child_pid) != 0) {
		if (signal_session(child_pid, identity.starttime, SIGKILL) != 0)
			fprintf(stderr, "pak spawn: failed to signal unreported session\n");
		waitpid(child_pid, &st, 0);
		return reap_session(child_pid, identity.starttime) == 0 ?
			127 : CLEANUP_FAILED;
	}

	for (;;) {
		pid_t got;

		if (stop_requested) {
			if (signal_session(child_pid, identity.starttime, SIGKILL) != 0)
				fprintf(stderr, "pak spawn: failed to stop session\n");
			waitpid(child_pid, &st, 0);
			return reap_session(child_pid, identity.starttime) == 0 ?
				128 + SIGTERM : CLEANUP_FAILED;
		}
		got = waitpid(child_pid, &st, 0);
		if (got == child_pid)
			break;
		if (got < 0 && errno == EINTR)
			continue;
		if (got < 0 && errno == ECHILD)
			break;
		if (got < 0)
			return 127;
	}
	if (reap_session(child_pid, identity.starttime) != 0) {
		fprintf(stderr, "pak spawn: session cleanup failed for %d\n",
			(int)child_pid);
		return CLEANUP_FAILED;
	}
	return child_status(st);
}
