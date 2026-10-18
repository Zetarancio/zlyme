#!/bin/sh
# rcS must start S21pulse after ALSA and before the jack watcher.
# No other boot script starts a second PulseAudio server.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
RCS=$ROOT/board/my355/fsoverlay/etc/init.d/rcS
LATE=$ROOT/board/my355/fsoverlay/etc/init.d/rc.late
S21=$ROOT/board/my355/fsoverlay/etc/init.d/S21pulse
S50=$ROOT/board/my355/fsoverlay/etc/init.d/S50pulseaudio
fail() { echo "pulse-boot: $*" >&2; exit 1; }

grep -q 'S21pulse' "$RCS" || fail "rcS whitelist omits S21pulse"
grep -q 'S21pulse' "$LATE" && fail "rc.late also starts PulseAudio"
grep -q 'ready_check &' "$S21" || fail "readiness check is not backgrounded"
grep -q 'echo OK' "$S21" && fail "S21pulse marks audio OK at launch"
# The replacement script must not launch the daemon.
if grep -v '^#' "$S50" | grep -q pulseaudio; then
	fail "S50pulseaudio still runs pulseaudio"
fi
grep -q '^exit 0$' "$S50" || fail "S50pulseaudio is not a no-op"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk '/^is_class_a\(\)/,/^}/' "$RCS" > "$work/class.sh"
# shellcheck disable=SC1091
. "$work/class.sh"
init=$work/init.d
mkdir -p "$init"
for name in S10udevd S11modules S20alsa S21pulse S22zram S25jackd S28minui S46btsink S50pulseaudio; do
	printf '#!/bin/sh\nprintf %%s\\n "$0"\n' > "$init/$name"
	chmod 755 "$init/$name"
done
order=$work/order
: > "$order"
for i in "$init"/S??*; do
	base=${i##*/}
	is_class_a "$base" || continue
	printf '%s\n' "$base" >> "$order"
done
got=$(paste -sd' ' "$order")
want="S10udevd S11modules S20alsa S21pulse S25jackd S28minui"
[ "$got" = "$want" ] || fail "class A order: $got"
# S21 sits after the mixer restore and before the jack mux.
alsa=$(grep -n '^S20alsa$' "$order" | cut -d: -f1)
pulse=$(grep -n '^S21pulse$' "$order" | cut -d: -f1)
jack=$(grep -n '^S25jackd$' "$order" | cut -d: -f1)
[ "$alsa" -lt "$pulse" ] && [ "$pulse" -lt "$jack" ] || fail "S21pulse is not between ALSA and jack"
echo "pulse boot ok"
