# Source this. zlyme_splash_wanted returns 0 when the kernel command
# line has a complete "quiet" token.
# ZLYME_CMDLINE is a test seam.

zlyme_splash_wanted() {
	_cmd=${ZLYME_CMDLINE:-/proc/cmdline}
	[ -r "$_cmd" ] || return 1
	_tok=
	# shellcheck disable=SC2013
	for _tok in $(cat "$_cmd"); do
		[ "$_tok" = quiet ] && return 0
	done
	return 1
}
