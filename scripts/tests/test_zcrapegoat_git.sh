#!/bin/sh
# Bundled Git lives in the PAK, not beside the ZcrapeGoat executable.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
src=$ROOT/package/system/zcrapegoat/src
pak=$ROOT/package/system/nextui/paks/Tools/ZcrapeGoat.pak
daemon=$src/src/daemon.c

test -x "$pak/resources/bin/git"
test -x "$pak/resources/bin/git-remote-https"
grep -q 'execl(self, self, "--daemon"' "$daemon"
if grep -q 'execle(' "$daemon" || grep -q 'clearenv(' "$daemon"; then
	echo "daemon re-exec no longer inherits the launcher environment" >&2
	exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/pak/resources/bin"

gcc -std=gnu11 -Wall -Wextra -O2 -o "$work/pak/resources/bin/git" -x c - << 'EOF'
#include <stdio.h>
#include <string.h>
extern char **environ;
int main(void) {
    char **entry;
    for (entry = environ; *entry; entry++) {
        if (strncmp(*entry, "GIT_EXEC_PATH=", 14) == 0 ||
            strncmp(*entry, "LD_LIBRARY_PATH=", 16) == 0)
            puts(*entry);
    }
    return 0;
}
EOF
chmod +x "$work/pak/resources/bin/git"
mkdir -p "$work/resources/bin" "$work/pathbin" "$work/empty"
cp "$work/pak/resources/bin/git" "$work/resources/bin/git"
cp "$work/pak/resources/bin/git" "$work/pathbin/git"
cp "$work/pak/resources/bin/git" "$work/pathbin/git-remote-https"
chmod +x "$work/resources/bin/git" "$work/pathbin/git" "$work/pathbin/git-remote-https"

gcc -std=gnu11 -Wall -Wextra -Wno-format-truncation -Wno-unused-function \
	-pthread -ffunction-sections -fdata-sections \
	-I "$src/src" -I "$src/third_party/cJSON" -I "$src/third_party/md5" \
	-I "$src/third_party/miniz" \
	-o "$work/resolve" \
	"$src/src/cheats.c" -x c - -Wl,--gc-sections -pthread << 'EOF'
#include "cheats.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern int run_git_capture(const char **argv, char *out, size_t cap);

static void die(const char *msg) {
    fprintf(stderr, "%s\n", msg);
    exit(1);
}

static char *resolved(const char *path) {
    char *got = realpath(path, NULL);
    if (!got)
        die("realpath");
    return got;
}

static void expect_child(const char *git, const char *exec_dir, const char *ld) {
    const char *child_argv[2];
    char out[1024];
    char exec_line[PATH_MAX];
    char ld_line[PATH_MAX];
    int execs = 0;
    int libs = 0;
    char *cursor;
    child_argv[0] = git;
    child_argv[1] = NULL;
    if (run_git_capture(child_argv, out, sizeof(out)) != 0)
        die("git helper failed");
    if (strstr(out, "resources/lib") != NULL)
        die("child library path invented resources/lib");
    snprintf(exec_line, sizeof(exec_line), "GIT_EXEC_PATH=%s", exec_dir);
    snprintf(ld_line, sizeof(ld_line), "LD_LIBRARY_PATH=%s", ld);
    cursor = out;
    while (cursor && *cursor) {
        char *nl = strchr(cursor, '\n');
        if (nl)
            *nl = '\0';
        if (strncmp(cursor, "GIT_EXEC_PATH=", 14) == 0) {
            execs++;
            if (strcmp(cursor, exec_line) != 0)
                die("child GIT_EXEC_PATH is not the selected helper directory");
        } else if (strncmp(cursor, "LD_LIBRARY_PATH=", 16) == 0) {
            libs++;
            if (strcmp(cursor, ld_line) != 0)
                die("child lost inherited LD_LIBRARY_PATH");
        }
        if (!nl)
            break;
        cursor = nl + 1;
    }
    if (execs != 1 || libs != 1)
        die("child environment did not have one helper path and one library path");
}

int main(int argc, char **argv) {
    char self[PATH_MAX];
    char exe_git[PATH_MAX];
    char path_git[PATH_MAX];
    const char *git;
    char *pak_git;
    char *exe_resolved;
    char *path_resolved;
    char *exe_dir;
    char *path_dir;
    ssize_t len;
    char *slash;
    if (argc != 4)
        die("usage");
    len = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (len <= 0)
        die("self");
    self[len] = '\0';
    slash = strrchr(self, '/');
    if (!slash)
        die("slash");
    *slash = '\0';
    snprintf(exe_git, sizeof(exe_git), "%s/resources/bin/git", self);
    snprintf(path_git, sizeof(path_git), "%s/git", argv[3]);
    {
        char pak_file[PATH_MAX];
        snprintf(pak_file, sizeof(pak_file), "%s/git", argv[1]);
        pak_git = resolved(pak_file);
    }
    exe_resolved = resolved(exe_git);
    path_resolved = resolved(path_git);
    exe_dir = resolved(self);
    {
        char rel[PATH_MAX];
        snprintf(rel, sizeof(rel), "%s/resources/bin", exe_dir);
        free(exe_dir);
        exe_dir = resolved(rel);
    }
    path_dir = resolved(argv[3]);

    setenv("PATH", argv[2], 1); /* empty directory: system git must not win */
    setenv("LD_LIBRARY_PATH", "/usr/lib:/tmp/zlyme-ld-keep", 1);
    setenv("GIT_EXEC_PATH", argv[1], 1);
    git = get_git_bin();
    if (!git || strcmp(git, pak_git) != 0)
        die("did not resolve PAK git");
    if (strcmp(git, exe_resolved) == 0)
        die("PAK case selected the executable-relative git");
    {
        char *pak_dir = resolved(argv[1]);
        expect_child(git, pak_dir, "/usr/lib:/tmp/zlyme-ld-keep");
        free(pak_dir);
    }

    unsetenv("GIT_EXEC_PATH");
    git = get_git_bin();
    if (!git || strcmp(git, exe_resolved) != 0)
        die("executable-relative git was not selected");
    expect_child(git, exe_dir, "/usr/lib:/tmp/zlyme-ld-keep");

    if (unlink(exe_git) != 0)
        die("unlink executable-relative git");
    setenv("PATH", argv[3], 1);
    git = get_git_bin();
    if (!git || strcmp(git, path_resolved) != 0)
        die("PATH git was not selected");
    if (strstr(git, "/resources/bin/git") != NULL)
        die("PATH fallback returned the executable-relative git");
    expect_child(git, path_dir, "/usr/lib:/tmp/zlyme-ld-keep");

    if (unlink(path_git) != 0)
        die("unlink PATH git");
    setenv("PATH", argv[2], 1);
    unsetenv("GIT_EXEC_PATH");
    if (get_git_bin() != NULL)
        die("resolver returned a git that does not exist");
    if (check_git_available() == 0)
        die("missing git was reported as available");

    free(pak_git);
    free(exe_resolved);
    free(path_resolved);
    free(exe_dir);
    free(path_dir);
    return 0;
}
EOF

"$work/resolve" "$work/pak/resources/bin" "$work/empty" "$work/pathbin"
echo "zcrapegoat git resource ok"
