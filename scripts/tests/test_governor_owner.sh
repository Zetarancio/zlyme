#!/bin/sh
# Frontend clocks are applied by the session, not by the LED service.
# A late reapply restores the profile already chosen.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
led=$ROOT/board/my355/fsoverlay/etc/init.d/S27led
session=$ROOT/package/system/nextui/nextui-session
update=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-update
gov=$ROOT/package/system/nextui/zlyme/governor.sh
keylid=$ROOT/package/system/zlyme-keylidmon/zlyme-keylidmon.c
floors=$ROOT/package/system/nextui/zlyme/test-governor-floors.sh

if grep -n 'apply-gov' "$led"; then
	echo "S27led still applies the governor" >&2
	exit 1
fi

awk '
	/apply_frontend_governor\(\)/ { def = NR }
	/^[[:space:]]*apply_frontend_governor$/ { call = NR }
	/nextui\.elf/ { elf = NR }
	END {
		if (!def || !call || !elf || !(call < elf)) {
			print "smart apply is not on the frontend start path" > "/dev/stderr"
			exit 1
		}
	}
' "$session"
grep -q 'zlyme-governor resume' "$session"
grep -q 'zlyme-governor smart' "$session"

awk '
	/^reapply_once\(\)/ { in_fn = 1 }
	in_fn && /^}/ { in_fn = 0 }
	in_fn && /apply-gov/ { bad = 1 }
	in_fn && /zlyme-governor resume/ { resume = 1 }
	END {
		if (bad || !resume) exit 1
	}
' "$update"

awk '
	/do_mem_sleep/ { fn = 1 }
	fn && /zlyme-governor idle/ && !idle { idle = NR }
	fn && /bin\/suspend/ && !sus { sus = NR }
	fn && /zlyme-governor resume/ && !res { res = NR }
	fn && /zlyme-radios resume/ && !rad { rad = NR }
	END {
		if (!(idle && sus && res && rad && idle < sus && sus < res && res < rad))
			exit 1
	}
' "$keylid"

sh "$floors"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_GOVERNOR_DRY=1
export ZLYME_GOVERNOR_LOCK=$work/lock
export ZLYME_GOVERNOR_PROFILE=$work/profile
export ZLYME_CPU_FREQS="408000 600000 816000 1104000 1416000 1608000 1800000 1992000"
test "$("$gov" smart)" = smart
grep -qx smart "$work/profile"
test "$("$gov" idle)" = idle
grep -qx smart "$work/profile"
test "$("$gov" resume)" = smart
test "$("$gov" emu GBA)" = "emu gba"
grep -qx "emu gba" "$work/profile"
test "$("$gov" resume)" = "emu gba"
test "$("$gov" idle)" = idle
grep -qx "emu gba" "$work/profile"
[ ! -e "$work/lock" ]

printf '%s\n' 999999 > "$work/lock"
test "$("$gov" smart)" = smart
grep -qx smart "$work/profile"
[ ! -e "$work/lock" ]

printf '%s\n' 'not-a-pid' > "$work/lock"
before=$(cat "$work/profile")
set +e
"$gov" play >"$work/bad.out" 2>"$work/bad.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "malformed governor lock was accepted" >&2
	exit 1
fi
grep -q malformed "$work/bad.err"
grep -qx 'not-a-pid' "$work/lock"
test "$(cat "$work/profile")" = "$before"

rm -f "$work/lock"
mkdir "$work/lock"
set +e
"$gov" play >"$work/dir.out" 2>"$work/dir.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "directory governor lock was accepted" >&2
	exit 1
fi
[ -d "$work/lock" ]
grep -q 'not a PID file' "$work/dir.err"
rm -rf "$work/lock"

printf '%s\n' smart > "$work/profile"
printf '%s\n' 1 > "$work/lock"
set +e
env ZLYME_GOVERNOR_LOCKED=1 "$gov" play >"$work/inh.out" 2>"$work/inh.err"
status=$?
set -e
if [ "$status" -eq 0 ]; then
	echo "inherited lock for another pid was trusted" >&2
	exit 1
fi
grep -q 'inherited lock' "$work/inh.err"
grep -qx smart "$work/profile"
grep -qx 1 "$work/lock"
rm -f "$work/lock"

wait_lock() {
	i=0
	while [ ! -f "$work/lock" ]; do
		i=$((i + 1))
		if [ "$i" -gt 40 ]; then
			echo "governor lock was not published" >&2
			exit 1
		fi
		sleep 0.05
	done
}

env ZLYME_GOVERNOR_HOLD=1 "$gov" play >"$work/hold.out" &
holder=$!
wait_lock
if env ZLYME_GOVERNOR_LOCK_TRIES=0 "$gov" heavy >"$work/steal.out" 2>"$work/steal.err"; then
	echo "live governor lock was stolen" >&2
	exit 1
fi
grep -q 'lock busy' "$work/steal.err"
owner=$(tr -d ' \t\r\n' < "$work/lock")
if [ "$owner" != "$holder" ]; then
	echo "lock owner is $owner, holder is $holder" >&2
	exit 1
fi
wait "$holder"
test "$(cat "$work/hold.out")" = play
grep -qx play "$work/profile"
[ ! -e "$work/lock" ]

printf '%s\n' smart > "$work/profile"
env ZLYME_GOVERNOR_HOLD=1 "$gov" play >"$work/race.out" &
holder=$!
wait_lock
resumed=$("$gov" resume)
wait "$holder"
if [ "$resumed" != play ]; then
	echo "delayed resume applied $resumed over play" >&2
	exit 1
fi
grep -qx play "$work/profile"
[ ! -e "$work/lock" ]

printf '%s\n' play > "$work/profile"
env ZLYME_GOVERNOR_HOLD=1 "$gov" resume >"$work/keep.out" &
holder=$!
wait_lock
owner=$(tr -d ' \t\r\n' < "$work/lock")
if [ "$owner" != "$holder" ]; then
	echo "resume dropped the lock (owner $owner holder $holder)" >&2
	exit 1
fi
if env ZLYME_GOVERNOR_LOCK_TRIES=0 "$gov" heavy >"$work/keep-steal.out" 2>"$work/keep-steal.err"; then
	echo "resume lock was stolen" >&2
	exit 1
fi
wait "$holder"
test "$(cat "$work/keep.out")" = play
grep -qx play "$work/profile"
[ ! -e "$work/lock" ]

: > "$work/mark"
python3 -c '
import os, signal, subprocess, sys, time
env = os.environ.copy()
env["ZLYME_GOVERNOR_HOLD"] = "30"
env["ZLYME_GOVERNOR_MARK"] = sys.argv[2]
env["ZLYME_GOVERNOR_LOCK_TRIES"] = "0"
p = subprocess.Popen([sys.argv[1], "heavy"], start_new_session=True, env=env)
lock = env["ZLYME_GOVERNOR_LOCK"]
for _ in range(40):
    if os.path.isfile(lock):
        break
    time.sleep(0.05)
else:
    print("governor lock was not published", file=sys.stderr)
    os.killpg(p.pid, signal.SIGKILL)
    sys.exit(1)
other = subprocess.run([sys.argv[1], "smart"], env=env, capture_output=True, text=True)
if other.returncode == 0:
    print("second profile applied while the lock was held", file=sys.stderr)
    print(other.stdout, file=sys.stderr)
    os.killpg(p.pid, signal.SIGKILL)
    sys.exit(1)
os.killpg(p.pid, signal.SIGINT)
try:
    rc = p.wait(timeout=3)
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    print("signal did not stop the governor", file=sys.stderr)
    sys.exit(1)
if rc != 130:
    print("INT status was %s" % rc, file=sys.stderr)
    sys.exit(1)
' "$gov" "$work/mark"
if [ -s "$work/mark" ]; then
	echo "signal path continued into the profile" >&2
	cat "$work/mark" >&2
	exit 1
fi
grep -qx heavy "$work/profile"
[ ! -e "$work/lock" ]

echo "governor owner ok"
