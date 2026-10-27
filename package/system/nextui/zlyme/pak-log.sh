# Sourced from launch.sh. Comment that line out to silence one pak.
# About → System logs. Logs on, this shell's stdout and stderr become
# the PAK file, including a libretro launch whose EMU_EXE is already
# set. ra-run adds -v and does not pass --log-file: RetroArch 1.22.2
# opens that path with "wb" and would erase this header.
#
# Three files per tag: TAG.log is this launch, TAG.log.1 and TAG.log.2
# are the two before it. Rotation is once, here, before anything writes.
# When system logs are off, this file creates nothing and does not rotate.
# A stock launch.sh does not open a second diagnostic file.
# ZLYME_LOG_ROOT and ZLYME_LOG_FORCE=1 are test seams.

PAK_LOG_GENERATIONS=3

zlyme_pak_rotate() {
	_rot_base=$1
	_rot_last=$((PAK_LOG_GENERATIONS - 1))
	rm -f "${_rot_base}.${_rot_last}"
	_rot_i=$_rot_last
	while [ "$_rot_i" -gt 1 ]; do
		_rot_prev=$((_rot_i - 1))
		if [ -f "${_rot_base}.${_rot_prev}" ]; then
			mv "${_rot_base}.${_rot_prev}" "${_rot_base}.${_rot_i}"
		fi
		_rot_i=$_rot_prev
	done
	if [ -f "$_rot_base" ]; then
		mv "$_rot_base" "${_rot_base}.1"
	fi
}

logs_wanted() {
	[ "${ZLYME_LOG_FORCE:-}" = 1 ] && return 0
	command -v zlyme-ctl >/dev/null 2>&1 && zlyme-ctl want logs
}

if logs_wanted; then
	tag=${EMU_TAG:-}
	if [ -z "$tag" ]; then
		tag=$(basename "$(dirname "$0")" .pak)
	fi
	_logroot=${ZLYME_LOG_ROOT:-/storage/.logs}
	mkdir -p "$_logroot/paks"
	export LOGS_PATH="$_logroot/paks"
	export ZLYME_PAK_LOG="$LOGS_PATH/${tag}.log"
	zlyme_pak_rotate "$ZLYME_PAK_LOG"
	printf '%s\n' "=== ${tag} $(date -u +%Y-%m-%dT%H:%M:%SZ) $ROM ===" >> "$ZLYME_PAK_LOG"
	unset _logroot
	# A failed exec redirection is fatal in BusyBox ash. Probe with an
	# ordinary command first. The probe only checks that the file can
	# be opened. It writes no data and does not prove a later write.
	# If the open fails, the launch keeps the caller's stdout and stderr.
	if cat /dev/null >>"$ZLYME_PAK_LOG" 2>/dev/null; then
		exec >>"$ZLYME_PAK_LOG" 2>&1
	fi
fi

if [ -n "${ROM:-}" ] && [ -r /usr/share/nextui/bin/zlyme-library.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/nextui/bin/zlyme-library.sh
	if ! zlyme_library_for "$ROM"; then
		echo "zlyme: launch setup failed for $ROM" >&2
		exit 1
	fi
fi
