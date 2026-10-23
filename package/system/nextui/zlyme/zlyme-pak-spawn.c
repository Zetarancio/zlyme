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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <dirent.h>
#include <unistd.h>

#define MAX_MEMBERS 128
#define TERM_POLLS 30
#define KILL_POLLS 10
#define POLL_US 50000

static volatile sig_atomic_t stop_requested;
static pid_t child_pid;

static void on_term(int sig)
{
	(void)sig;
	stop_requested = 1;
}

static int parse_ids(const char *line, pid_t *pgid, pid_t *sid)
{
	const char *rest;
	long pgrp, session;

	rest = strrchr(line, ')');
	if (!rest || rest[1] == '\0')
		return -1;
	if (sscanf(rest + 1, " %*c %*d %ld %ld", &pgrp, &session) != 2)
		return -1;
	*pgid = (pid_t)pgrp;
	*sid = (pid_t)session;
	return 0;
}

static int read_ids(pid_t pid, pid_t *pgid, pid_t *sid)
{
	char path[64];
	char buf[512];
	ssize_t n;
	int fd;

	if (pid <= 0)
		return -1;
	snprintf(path, sizeof path, "/proc/%d/stat", (int)pid);
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	n = read(fd, buf, sizeof buf - 1);
	close(fd);
	if (n <= 0)
		return -1;
	buf[n] = '\0';
	return parse_ids(buf, pgid, sid);
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

static int collect_members(pid_t leader, pid_t *out, int cap)
{
	DIR *dir;
	struct dirent *ent;
	int n = 0;

	if (own_session(leader))
		return 0;
	dir = opendir("/proc");
	if (!dir)
		return 0;
	while ((ent = readdir(dir))) {
		pid_t pid, pgid, sid;
		char *end;

		if (ent->d_name[0] < '1' || ent->d_name[0] > '9')
			continue;
		pid = (pid_t)strtol(ent->d_name, &end, 10);
		if (*end != '\0' || pid <= 1 || pid == getpid() || pid == leader)
			continue;
		if (read_ids(pid, &pgid, &sid) != 0)
			continue;
		if (sid != leader)
			continue;
		if (n < cap)
			out[n++] = pid;
	}
	closedir(dir);
	return n;
}

static int session_busy(pid_t leader)
{
	pid_t one;

	return collect_members(leader, &one, 1) > 0;
}

static void signal_session(pid_t leader, int sig)
{
	pid_t members[MAX_MEMBERS];
	int n, i;

	if (own_session(leader))
		return;
	kill(-leader, sig);
	n = collect_members(leader, members, MAX_MEMBERS);
	for (i = 0; i < n; i++) {
		pid_t pgid, sid;

		if (read_ids(members[i], &pgid, &sid) != 0)
			continue;
		if (sid != leader || own_session(leader))
			continue;
		kill(members[i], sig);
	}
}

static void reap_session(pid_t leader)
{
	int i;

	/* An empty session is not a target. kill(-pgid) on a reused id
	 * would hit a different group. */
	if (!session_busy(leader))
		return;
	signal_session(leader, SIGTERM);
	for (i = 0; i < TERM_POLLS; i++) {
		if (!session_busy(leader))
			return;
		usleep(POLL_US);
	}
	signal_session(leader, SIGKILL);
	for (i = 0; i < KILL_POLLS; i++) {
		if (!session_busy(leader))
			return;
		usleep(POLL_US);
	}
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
	if (WIFEXITED(st))
		return WEXITSTATUS(st);
	if (WIFSIGNALED(st))
		return 128 + WTERMSIG(st);
	return 1;
}

int main(int argc, char **argv)
{
	int fds[2];
	int st = 0;
	char ok = 0;
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
		close(fds[0]);
		if (setsid() < 0)
			_exit(127);
		ok = 1;
		if (write(fds[1], &ok, 1) != 1)
			_exit(127);
		close(fds[1]);
		execvp(argv[2], &argv[2]);
		_exit(127);
	}
	close(fds[1]);
	if (read(fds[0], &ok, 1) != 1) {
		close(fds[0]);
		waitpid(child_pid, &st, 0);
		return 127;
	}
	close(fds[0]);
	if (write_leader(argv[1], child_pid) != 0) {
		signal_session(child_pid, SIGKILL);
		waitpid(child_pid, &st, 0);
		reap_session(child_pid);
		return 127;
	}

	for (;;) {
		pid_t got;

		if (stop_requested) {
			signal_session(child_pid, SIGKILL);
			waitpid(child_pid, &st, 0);
			reap_session(child_pid);
			return 128 + SIGTERM;
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
	reap_session(child_pid);
	return child_status(st);
}
