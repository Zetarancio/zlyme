#!/bin/sh
# Host checks for bounded system and PAK logs. Does not touch /storage.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
LOGS="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-logs"
PAK="$ROOT/package/system/nextui/zlyme/pak-log.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sys=$work/logs
mark=$work/run/zlyme-logs-generation
mkdir -p "$work/run"

boot() {
	rm -f "$mark"
	ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" start
	cur=$(ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" current)
	printf '%s\n' "$1" > "$cur/id"
}

n=1
while [ "$n" -le 7 ]; do
	boot "$n"
	n=$((n + 1))
done

cur=$(ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" current)
[ "$(cat "$cur/id")" = 7 ]
[ "$(cat "$sys/system-0/id")" = 7 ]
[ "$(cat "$sys/system-1/id")" = 6 ]
[ "$(cat "$sys/system-2/id")" = 5 ]
[ "$(cat "$sys/system-3/id")" = 4 ]
[ "$(cat "$sys/system-4/id")" = 3 ]
test ! -d "$sys/system-5"
test ! -d "$sys/system-6"

# Second start in the same boot does not rotate.
printf '%s\n' same > "$sys/system-0/id"
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" start
[ "$(cat "$sys/system-0/id")" = same ]
[ "$(cat "$sys/system-1/id")" = 6 ]

# Off then On in the same boot does not rotate either.
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" stop
ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$sys" ZLYME_LOG_MARK="$mark" "$LOGS" start
[ "$(cat "$sys/system-0/id")" = same ]
[ "$(cat "$sys/system-1/id")" = 6 ]
test -f "$mark"

# Logging off does not create a generation.
off=$work/off
offmark=$work/off-mark
ZLYME_LOG_ROOT="$off" ZLYME_LOG_MARK="$offmark" "$LOGS" start
test ! -d "$off/system-0"
test ! -f "$offmark"

paks=$work/paks-root
launch() {
	tag=$1
	id=$2
	EMU_TAG=$tag EMU_EXE=core ROM= \
		ZLYME_LOG_FORCE=1 ZLYME_LOG_ROOT="$paks" \
		. "$PAK"
	printf 'LAUNCH %s\n' "$id" >> "$ZLYME_PAK_LOG"
}

i=1
while [ "$i" -le 5 ]; do
	launch GBA "$i"
	i=$((i + 1))
done
grep -q 'LAUNCH 5' "$paks/paks/GBA.log"
grep -q 'LAUNCH 4' "$paks/paks/GBA.log.1"
grep -q 'LAUNCH 3' "$paks/paks/GBA.log.2"
test ! -e "$paks/paks/GBA.log.3"
grep -q 'LAUNCH 5' "$paks/paks/GBA.log.1" && exit 1
grep -q 'LAUNCH 1' "$paks/paks/GBA.log" && exit 1
grep -q 'LAUNCH 1' "$paks/paks/GBA.log.1" && exit 1
grep -q 'LAUNCH 1' "$paks/paks/GBA.log.2" && exit 1
grep -q 'LAUNCH 2' "$paks/paks/GBA.log.2" && exit 1

launch PSP 1
launch PSP 2
grep -q 'LAUNCH 2' "$paks/paks/PSP.log"
grep -q 'LAUNCH 1' "$paks/paks/PSP.log.1"
grep -q 'LAUNCH 5' "$paks/paks/GBA.log"

quiet=$work/quiet
unset ZLYME_LOG_FORCE
EMU_TAG=GBA EMU_EXE=core ROM= ZLYME_LOG_ROOT="$quiet" . "$PAK"
test ! -e "$quiet/paks/GBA.log"

echo "log history ok"
