#!/bin/sh
# Host check for Spruce floor resolution. Does not touch sysfs.
set -eu
cd "$(dirname "$0")"
gov=./governor.sh
freqs="408000 600000 816000 1104000 1416000 1608000 1800000 1992000"
fail=0

expect_floor() {
	req=$1
	want=$2
	got=$(ZLYME_CPU_FREQS="$freqs" "$gov" --resolve-floor "$req")
	if [ "$got" != "$want" ]; then
		printf 'floor %s -> %s, want %s\n' "$req" "$got" "$want" >&2
		fail=1
	fi
}

expect_policy() {
	tag=$1
	want=$2
	got=$(ZLYME_CPU_FREQS="$freqs" "$gov" --policy "$tag")
	if [ "$got" != "$want" ]; then
		printf 'policy %s -> %s, want %s\n' "$tag" "$got" "$want" >&2
		fail=1
	fi
}

expect_floor 240000 408000
expect_floor 312000 408000
expect_floor 408000 408000
expect_floor 480000 600000
expect_floor 648000 816000
expect_floor 816000 816000
expect_floor 1008000 1104000

expect_policy GBA "spruce=816000 effective=816000 profile=spruce"
expect_policy GB "spruce=240000 effective=408000 profile=spruce"
expect_policy PS "spruce=1008000 effective=1104000 profile=spruce"
expect_policy PSP "spruce=1008000 effective=1104000 profile=spruce"
expect_policy N64 "spruce=1008000 effective=1104000 profile=spruce"
expect_policy PS2 "spruce= effective= profile=heavy"
expect_policy GC "spruce= effective= profile=heavy"
expect_policy WII "spruce= effective= profile=heavy"
expect_policy WINE "spruce= effective= profile=play"
expect_policy 3DO "spruce= effective= profile=play"
expect_policy DAPHNE "spruce= effective= profile=play"

# Every shipped emulator tag must resolve.
for pak in ../paks/Emus/*.pak; do
	tag=$(basename "$pak" .pak)
	got=$(ZLYME_CPU_FREQS="$freqs" "$gov" --policy "$tag")
	case "$got" in
		spruce=[0-9]*" effective="[0-9]*" profile=spruce") ;;
		"spruce= effective= profile=heavy") ;;
		"spruce= effective= profile=play") ;;
		*)
			printf 'unresolved %s -> %s\n' "$tag" "$got" >&2
			fail=1
			;;
	esac
done

if [ "$fail" -ne 0 ]; then
	exit 1
fi
printf 'governor floors ok\n'
