#!/bin/sh
# Host checks for the pak session helper. No device and no /storage writes.
set -eu
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
LAUNCH=$ROOT/package/system/nextui/zlyme/pak-launch.sh
cc=${CC:-gcc}

fail() {
	echo "pak spawn: $*" >&2
	exit 1
}

[ -f "$LAUNCH" ] || fail "missing pak-launch.sh"
work=$(mktemp -d)
owned=$work/owned
: > "$owned"
restore() {
	if [ -f "$owned" ]; then
		while read -r pid; do
			[ -n "$pid" ] || continue
			kill -KILL "$pid" 2>/dev/null || true
		done < "$owned"
	fi
	rm -rf "$work"
}
trap restore EXIT
note() {
	printf '%s\n' "$1" >> "$owned"
}

"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/zlyme-pak-spawn" \
	"$ROOT/package/system/nextui/zlyme/zlyme-pak-spawn.c"
"$cc" -std=gnu99 -Wall -Wextra -Werror -o "$work/survivor" -x c - << 'EOF'
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static void on_term(int sig)
{
	const char *path;
	FILE *f;
	(void)sig;
	path = getenv("SURVIVOR_MARK");
	if (!path)
		return;
	f = fopen(path, "a");
	if (!f)
		return;
	fputs("term\n", f);
	fclose(f);
}
int main(void)
{
	signal(SIGTERM, on_term);
	for (;;)
		pause();
	return 0;
}
EOF

mkdir -p "$work/bin" "$work/tree/Emus/my355/PORTS.pak" \
	"$work/tree/Emus/my355/GB.pak"
cp "$work/zlyme-pak-spawn" "$work/bin/zlyme-pak-spawn"
chmod 0755 "$work/bin/zlyme-pak-spawn"
cat > "$work/bin/drm" << 'EOF'
#!/bin/sh
exit 0
EOF
cat > "$work/bin/pm" << 'EOF'
#!/bin/sh
printf '%s\n' clean >> "${SEQ:-/dev/null}"
EOF
cat > "$work/bin/hotkey" << 'EOF'
#!/bin/sh
printf '%s\n' "$1" > "$OUT/hotkey-pid"
ps -o sid= -p "$1" | tr -d ' \n' > "$OUT/hotkey-sid"
sleep 0.2
kill -TERM -- "-$1" 2>/dev/null || true
while :; do
	sleep 1
done
EOF
chmod 0755 "$work/bin/drm" "$work/bin/pm" "$work/bin/hotkey"

# shellcheck disable=SC1090
. "$LAUNCH"
export PATH="$work/bin:/usr/bin:/bin"
export ZLYME_PAK_BT=0
export ZLYME_PAK_LAUNCH_SH="$LAUNCH"
export ZLYME_DRM_RELEASE="$work/bin/drm"
export ZLYME_PORTMASTER_CLEANUP="$work/bin/pm"
export ZLYME_PAK_HOTKEY="$work/missing-hotkey"
export SESSION_LOG="$work/session.log"
export LOGS_ON=0
export SURVIVOR="$work/survivor"
unset ZLYME_PAK_TRACE ZLYME_PAK_SPAWN || true

ports=$work/tree/Emus/my355/PORTS.pak/launch.sh
emu=$work/tree/Emus/my355/GB.pak/launch.sh

wait_bound() {
	pid=$1
	label=$2
	i=0
	while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 80 ]; do
		sleep 0.1
		i=$((i + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		fail "$label did not finish"
	fi
	wait "$pid" 2>/dev/null || true
}

# Clean exit. The recorded leader is its own session.
cat > "$emu" << 'EOF'
#!/bin/sh
printf '%s\n' "$$" > "$OUT/pid"
ps -o sid= -p "$$" | tr -d ' \n' > "$OUT/sid"
exit 0
EOF
chmod 0755 "$emu"
OUT=$work/clean
mkdir -p "$OUT"
export OUT
run_pak_cmd "$emu" "/r/a"
# shellcheck disable=SC2154 # set by run_pak_cmd
[ "$st" -eq 0 ] || fail "clean status $st"
[ "$(cat "$OUT/pid")" = "$(cat "$OUT/sid")" ] || fail "clean leader is not its session"
# shellcheck disable=SC2154 # set by spawn_pak
[ "$(cat "$OUT/pid")" = "$_pak_pid" ] || fail "clean target is not the leader"

# Long-running leader. The stub hotkey signals that leader's group.
cat > "$emu" << 'EOF'
#!/bin/sh
printf '%s\n' "$$" > "$OUT/pid"
exec sleep 30
EOF
chmod 0755 "$emu"
OUT=$work/long
mkdir -p "$OUT"
export OUT
export ZLYME_PAK_HOTKEY="$work/bin/hotkey"
run_pak_cmd "$emu" "/r/a" &
job=$!
note "$job"
i=0
while [ ! -s "$OUT/hotkey-pid" ] && [ "$i" -lt 50 ]; do
	sleep 0.05
	i=$((i + 1))
done
[ -s "$OUT/hotkey-pid" ] || fail "long-running hotkey did not see a leader"
leader=$(cat "$OUT/hotkey-pid")
sid=$(cat "$OUT/hotkey-sid")
[ "$leader" = "$sid" ] || fail "long-running target sid $sid is not leader $leader"
[ "$leader" != "$$" ] || fail "long-running target is the test shell"
wait_bound "$job" "long-running child"
[ ! -d "/proc/$leader" ] || fail "long-running leader $leader survived"

# Short-lived wrapper. The leader exits and leaves a child that ignores
# SIGTERM. The helper must still end that child, then port cleanup runs.
cat > "$ports" << 'EOF'
#!/bin/sh
"$SURVIVOR" &
printf '%s\n' "$!" > "$OUT/child"
exit 0
EOF
chmod 0755 "$ports"
OUT=$work/wrap
mkdir -p "$OUT"
export OUT SURVIVOR_MARK="$OUT/mark"
export ZLYME_PAK_HOTKEY="$work/missing-hotkey"
SEQ=$OUT/seq
export SEQ
: > "$SEQ"
run_pak_cmd "$ports" "/r/a" &
job=$!
note "$job"
wait_bound "$job" "wrapper child"
[ -s "$OUT/child" ] || fail "wrapper did not start a child"
child=$(cat "$OUT/child")
[ ! -d "/proc/$child" ] || fail "wrapper child $child survived"
grep -q term "$OUT/mark" || fail "wrapper child was not sent SIGTERM"
grep -q clean "$SEQ" || fail "wrapper skipped port cleanup"

# This shell's sleeper shares the frontend session. A pak that exits
# must not signal it.
cat > "$emu" << 'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$emu"
sleep 30 &
innocent=$!
note "$innocent"
OUT=$work/safe
mkdir -p "$OUT"
export OUT
run_pak_cmd "$emu" "/r/a"
if ! kill -0 "$innocent" 2>/dev/null; then
	fail "frontend sleeper was signaled"
fi
kill "$innocent" 2>/dev/null || true
wait "$innocent" 2>/dev/null || true

echo "pak spawn ok"
