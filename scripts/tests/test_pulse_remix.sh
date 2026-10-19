#!/bin/sh
# shellcheck disable=SC1007
# PulseAudio 17 maps mono onto a stereo sink only when remixing is on.
# enable-remixing=no sets PA_RESAMPLER_NO_REMIX. Name matching then
# leaves both front channels at zero. daemon.conf must not set that.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "pulse-remix: $*" >&2; exit 1; }
conf=$ROOT/board/my355/fsoverlay/etc/pulse/daemon.conf
if grep -q '^enable-remixing' "$conf"; then
	fail "daemon.conf overrides remixing"
fi
grep -q '^flat-volumes = no' "$conf" || fail "flat volumes changed"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/remix.c" << 'EOF'
/* PulseAudio 17 src/pulsecore/resampler.c setup_remap.
 * NO_REMIX copies a channel only when the position names match.
 * Mono is not front-left or front-right, so a stereo sink stays
 * silent. The default path copies mono onto every non-LFE channel. */
enum { CH_MONO = 1, CH_FL = 2, CH_FR = 3, CH_LFE = 4 };
static void map_noremix(const int *in_pos, int n_in, const int *out_pos,
			 int n_out, float m[8][8])
{
	int oc, ic;
	for (oc = 0; oc < n_out; oc++)
		for (ic = 0; ic < n_in; ic++)
			if (in_pos[ic] == out_pos[oc])
				m[oc][ic] = 1.0f;
}
static void map_remix_mono(const int *out_pos, int n_out, float m[8][8])
{
	int oc;
	for (oc = 0; oc < n_out; oc++)
		m[oc][0] = out_pos[oc] == CH_LFE ? 0.0f : 1.0f;
}
static void apply(const float m[8][8], int n_out, int n_in, const int *in,
		  int *out)
{
	int oc, ic;
	for (oc = 0; oc < n_out; oc++) {
		float s = 0;
		for (ic = 0; ic < n_in; ic++)
			s += m[oc][ic] * (float)in[ic];
		out[oc] = (int)s;
	}
}
int main(void)
{
	int in_pos[] = { CH_MONO };
	int out_pos[] = { CH_FL, CH_FR };
	int samples[] = { 1000, -2000, 400 };
	int i;
	float off[8][8] = {{0}};
	float on[8][8] = {{0}};
	map_noremix(in_pos, 1, out_pos, 2, off);
	map_remix_mono(out_pos, 2, on);
	for (i = 0; i < 3; i++) {
		int silenced[2];
		int heard[2];
		int one[1];
		one[0] = samples[i];
		apply(off, 2, 1, one, silenced);
		apply(on, 2, 1, one, heard);
		if (silenced[0] != 0 || silenced[1] != 0)
			return 1;
		if (heard[0] != samples[i] || heard[1] != samples[i])
			return 2;
	}
	return 0;
}
EOF
cc -std=c11 -Wall -Wextra -Werror -o "$work/remix" "$work/remix.c"
"$work/remix"
echo "pulse remix ok"
