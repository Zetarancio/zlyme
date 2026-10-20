#!/bin/sh
# shellcheck disable=SC1007
# The ALSA card id is the token in brackets. The kernel short name
# after the bracket is not a hw: id. Card 1 is not hardcoded.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-card: $*" >&2; exit 1; }

cards=$ROOT/board/my355/fsoverlay/etc/asound.conf
pa=$ROOT/board/my355/fsoverlay/etc/pulse/zlyme.pa
audio=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-audio
s20=$ROOT/board/my355/fsoverlay/etc/init.d/S20alsa
jack=$ROOT/package/system/zlyme-jackd/src/zlyme-jackd.c

for f in "$cards" "$pa" "$audio" "$s20"; do
	if grep -q 'hw:rk817_ext' "$f"; then
		fail "$f uses the kernel short name as an ALSA id"
	fi
	if grep -q 'hw:1,0' "$f"; then
		fail "$f hardcodes ALSA card 1"
	fi
done
grep -q 'hw:rk817ext,0' "$pa" || fail "codec sink does not use the card id"
grep -q 'alsa.id = "rk817ext"' "$ROOT/board/my355/fsoverlay/usr/share/wireplumber/wireplumber.conf.d/51-zlyme.conf" || fail "wireplumber lost the card id"
grep -q 'CARD=rk817ext' "$s20" || fail "mixer restore lost the card id"
grep -q 'Playback Mux' "$jack" || fail "jack watcher lost Playback Mux"
grep -q 'CARD_ID "hw:rk817ext"' "$jack" || fail "jack watcher lost the card id"
grep -q 'JACK_NAME "rk817_ext Headphones"' "$jack" || fail "jack input name is not the kernel name"
grep -q 'Playback Mux' "$jack" || fail "jack watcher lost the physical mux"

# A cards file where the codec is not index 0. The id is inside the
# brackets. The short name is the other token.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/cards" << 'EOF'
 0 [HDMI           ]: simple-card - HDMI
                      HDMI
 1 [rk817ext       ]: simple-card - rk817_ext
                      rk817_ext
EOF
ids=$(sed -n 's/^ *[0-9][0-9]* \[\([^]]*\)\].*/\1/p' "$work/cards" | tr -d ' ')
[ "$ids" = "HDMI
rk817ext" ] || fail "parsed ids: $ids"
printf '%s\n' "$ids" | grep -qx rk817_ext && fail "kernel short name was parsed as the id"
echo "pulse card ok"
