# Sourced from launch.sh. Comment that line out to silence one pak.
# About → System logs. RetroArch cores (EMU_EXE set) get --log-file via
# ra-run. Standalones and Tools inherit stdout/stderr on the same file.

if command -v zlyme-ctl >/dev/null 2>&1 && zlyme-ctl want logs; then
	tag=${EMU_TAG:-}
	if [ -z "$tag" ]; then
		tag=$(basename "$(dirname "$0")" .pak)
	fi
	mkdir -p /storage/.logs
	export LOGS_PATH=/storage/.logs
	export ZLYME_PAK_LOG=/storage/.logs/${tag}.log
	printf '%s\n' "=== ${tag} $(date -u +%Y-%m-%dT%H:%M:%SZ) $ROM ===" >> "$ZLYME_PAK_LOG"
	if [ -z "$EMU_EXE" ]; then
		exec >>"$ZLYME_PAK_LOG" 2>&1
	fi
fi

if [ -n "${ROM:-}" ] && [ -r /usr/share/nextui/bin/zlyme-library.sh ]; then
	. /usr/share/nextui/bin/zlyme-library.sh
	zlyme_library_for "$ROM"
fi
