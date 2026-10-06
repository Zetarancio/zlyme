#!/usr/bin/env bash
# Run a build command. The full output stays in the log file. The console
# receives Buildroot lifecycle lines and useful errors as they are produced.
# The exit status is the command's. grep's status is ignored.
set -u

if [ "$#" -lt 2 ]; then
	echo "usage: stream-build-log.sh LOGFILE COMMAND..." >&2
	exit 2
fi

log=$1
shift
mkdir -p "$(dirname "$log")"

filter='>>> .*(Downloading|Extracting|Patching|Configuring|Building|Installing)|(error:|Error:|ERROR:|make: \*\*\*|collect2: error|undefined reference|Killed|No space left)'

set +e
set +o pipefail
if command -v stdbuf >/dev/null 2>&1; then
	stdbuf -oL -eL "$@" 2>&1 |
		tee "$log" |
		{ stdbuf -oL grep -E --line-buffered "$filter" || true; }
else
	"$@" 2>&1 |
		tee "$log" |
		{ grep -E "$filter" || true; }
fi
exit "${PIPESTATUS[0]}"
