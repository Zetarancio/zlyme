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
    int execs = 0;
    int libs = 0;
    char **entry;
    for (entry = environ; *entry; entry++) {
        if (strncmp(*entry, "GIT_EXEC_PATH=", 14) == 0) {
            puts(*entry);
            execs++;
        } else if (strncmp(*entry, "LD_LIBRARY_PATH=", 16) == 0) {
            puts(*entry);
            libs++;
        }
    }
    if (execs != 1 || libs != 1)
        return 2;
    return 0;
}
EOF
chmod +x "$work/pak/resources/bin/git"

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

int main(int argc, char **argv) {
    char self[PATH_MAX];
    char exe_git[PATH_MAX];
    char out[1024];
    const char *git;
    const char *child_argv[2];
    ssize_t len;
    char *slash;
    if (argc != 3)
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

    setenv("GIT_EXEC_PATH", argv[1], 1);
    setenv("LD_LIBRARY_PATH", argv[2], 1);
    git = get_git_bin();
    if (strcmp(git, exe_git) == 0)
        die("resolved executable-relative git");
    if (strstr(git, "/usr/lib/zlyme/zcrapegoat/resources/bin/git") != NULL)
        die("resolved install-relative git");
    {
        char expect[PATH_MAX];
        snprintf(expect, sizeof(expect), "%s/git", argv[1]);
        if (strcmp(git, expect) != 0)
            die("did not resolve PAK git");
    }
    child_argv[0] = git;
    child_argv[1] = NULL;
    if (run_git_capture(child_argv, out, sizeof(out)) != 0)
        die("git helper failed");
    {
        char expect[PATH_MAX];
        snprintf(expect, sizeof(expect), "GIT_EXEC_PATH=%s\n", argv[1]);
        if (strstr(out, expect) == NULL)
            die("child lost PAK GIT_EXEC_PATH");
        if (strstr(out, "/resources/bin\n") != NULL && strstr(out, argv[1]) == NULL)
            die("child git path is not the PAK directory");
        if (strstr(out, "resources/lib") != NULL)
            die("child library path invented resources/lib");
        snprintf(expect, sizeof(expect), "LD_LIBRARY_PATH=%s\n", argv[2]);
        if (strstr(out, expect) == NULL)
            die("child lost inherited LD_LIBRARY_PATH");
    }

    unsetenv("GIT_EXEC_PATH");
    git = get_git_bin();
    if (strcmp(git, exe_git) != 0)
        die("fallback is not executable-relative");
    return 0;
}
EOF

"$work/resolve" "$work/pak/resources/bin" "/usr/lib:/tmp/zlyme-ld-keep"
echo "zcrapegoat git resource ok"
