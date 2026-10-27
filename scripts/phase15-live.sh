#!/bin/sh
# Selected launches through the existing nextui-session.
# /tmp/next is a ZLYME1 record. This does not kill nextui-session,
# and it does not signal every emulator on the system.
set -u

LOG=${ZLYME_PHASE15_LOG:-/tmp/phase15-live.log}
RES=${ZLYME_PHASE15_RES:-/tmp/phase15-live.txt}
STAGE=/tmp/zlyme-phase15-next
HANDED=0

log() { printf '%s\n' "$*" | tee -a "$LOG"; }
result() { printf '%s\n' "$*" | tee -a "$LOG" >> "$RES"; }

: > "$LOG"
: > "$RES"

cleanup() {
	rm -f "$STAGE"
	if [ "$HANDED" = 0 ] && [ -f /tmp/next ]; then
		_mag=$(sed -n '1p' /tmp/next 2>/dev/null || true)
		if [ "$_mag" = ZLYME1 ]; then
			rm -f /tmp/next
		fi
	fi
}
trap cleanup EXIT

drm_lines() {
	_p=
	for _p in /proc/[0-9]*; do
		[ -d "$_p/fd" ] || continue
		_pid=${_p#/proc/}
		_hit=0
		for _fd in "$_p"/fd/*; do
			_t=$(readlink "$_fd" 2>/dev/null || true)
			case "$_t" in
				/dev/dri/card0*) _hit=1 ;;
			esac
			[ "$_hit" = 1 ] && break
		done
		[ "$_hit" = 1 ] || continue
		_cmd=$(tr '\000' ' ' < "$_p/cmdline" 2>/dev/null || true)
		printf 'drm pid=%s cmd=%s\n' "$_pid" "$_cmd"
	done
}

session_pid() {
	pidof nextui-session 2>/dev/null | awk '{print $1}'
}

nextui_pid() {
	pidof nextui.elf 2>/dev/null | awk '{print $1}'
}

allowed_drm() {
	_cmd=$1
	_ok=$2
	case "$_cmd" in
		*nextui.elf*) return 0 ;;
	esac
	if [ -n "$_ok" ] && [ -n "$_cmd" ]; then
		case "$_cmd" in
			*"$_ok"*) return 0 ;;
		esac
	fi
	return 1
}

drm_unexpected() {
	_ok=$1
	_bad=0
	_line=
	drm_lines | while IFS= read -r _line; do
		printf '%s\n' "$_line"
	done > /tmp/phase15-drm.txt
	while IFS= read -r _line; do
		[ -n "$_line" ] || continue
		log "$_line"
		_cmd=${_line#*cmd=}
		if ! allowed_drm "$_cmd" "$_ok"; then
			_bad=1
		fi
	done < /tmp/phase15-drm.txt
	[ "$_bad" = 0 ]
}

virt_event() {
	_d=
	for _d in /sys/class/input/input*; do
		[ -r "$_d/name" ] || continue
		_name=$(tr -d '\r\n' < "$_d/name")
		[ "$_name" = "Microsoft X-Box 360 pad" ] || continue
		_node=$(readlink -f "$_d" 2>/dev/null || true)
		case "$_node" in
			*/devices/virtual/input/*) ;;
			*) continue ;;
		esac
		_ev=
		for _ev in "$_d"/event*; do
			[ -d "$_ev" ] || continue
			_base=$(basename "$_ev")
			if [ -e "/dev/input/$_base" ]; then
				printf '%s\n' "/dev/input/$_base"
				return 0
			fi
		done
	done
	return 1
}

chord() {
	_ev=$1
	python3 - "$_ev" << 'PY'
import os, struct, sys, time
EV_SYN, EV_KEY = 0, 1
BTN_START, BTN_MODE = 0x13b, 0x13c
def pkt(t, c, v):
    return struct.pack("llHHi", 0, 0, t, c, v)
fd = os.open(sys.argv[1], os.O_WRONLY)
os.write(fd, pkt(EV_KEY, BTN_MODE, 1) + pkt(EV_KEY, BTN_START, 1) + pkt(EV_SYN, 0, 0))
time.sleep(0.4)
os.write(fd, pkt(EV_KEY, BTN_MODE, 0) + pkt(EV_KEY, BTN_START, 0) + pkt(EV_SYN, 0, 0))
os.close(fd)
PY
}

wait_pid_gone() {
	_pid=$1
	_n=$2
	_i=0
	while [ "$_i" -lt "$_n" ]; do
		kill -0 "$_pid" 2>/dev/null || return 0
		sleep 0.2
		_i=$((_i + 1))
	done
	return 1
}

wait_name() {
	_name=$1
	_n=$2
	_i=0
	while [ "$_i" -lt "$_n" ]; do
		pidof "$_name" >/dev/null 2>&1 && return 0
		sleep 0.2
		_i=$((_i + 1))
	done
	return 1
}

wait_nextui() {
	wait_name nextui.elf "$1"
}

write_record() {
	_exe=$1
	_rom=${2-}
	case "$_exe" in
		/*/launch.sh) ;;
		*)
			log "record rejected: launcher"
			return 1
			;;
	esac
	[ -f "$_exe" ] || {
		log "record rejected: launcher missing"
		return 1
	}
	if [ -n "$_rom" ]; then
		case "$_rom" in
			/*) ;;
			*)
				log "record rejected: rom"
				return 1
				;;
		esac
		[ -f "$_rom" ] || {
			log "record rejected: rom missing"
			return 1
		}
		printf 'ZLYME1\n2\n%s\n%s\n' "$_exe" "$_rom" > "$STAGE"
	else
		printf 'ZLYME1\n1\n%s\n' "$_exe" > "$STAGE"
	fi
	return 0
}

markers() {
	log "markers binds_ppsspp=$( [ -e /tmp/zlyme-ppsspp-binds ] && wc -c < /tmp/zlyme-ppsspp-binds || echo absent ) unresolved=$( [ -e /tmp/zlyme-ppsspp-unresolved ] && echo yes || echo no ) cleanup=$( [ -e /run/zlyme/pak-cleanup-failed ] && echo yes || echo no )"
	awk '$5 ~ /ppsspp|dolphin-emu|flycast/ {print}' /proc/self/mountinfo 2>/dev/null | while IFS= read -r _m; do
		log "mount $_m"
	done
}

blocked() {
	result "BLOCKED $*"
	return 1
}

handoff() {
	_tag=$1
	_exe=$2
	_rom=$3
	_proc=$4
	_sess=
	_ui=
	_nui=
	log ""
	log "=== $_tag ==="
	_sess=$(session_pid || true)
	if [ -z "$_sess" ]; then
		blocked "$_tag no-session"
		return 1
	fi
	if [ "$(pidof nextui-session 2>/dev/null | wc -w)" -ne 1 ]; then
		blocked "$_tag session-count"
		return 1
	fi
	log "drm before"
	if ! drm_unexpected ""; then
		blocked "$_tag unexpected-drm-before"
		return 1
	fi
	_ui=$(nextui_pid || true)
	if [ -z "$_ui" ]; then
		blocked "$_tag no-nextui"
		return 1
	fi
	_cmd=$(tr '\000' ' ' < "/proc/$_ui/cmdline" 2>/dev/null || true)
	case "$_cmd" in
		*nextui.elf*) ;;
		*)
			blocked "$_tag nextui-identity"
			return 1
			;;
	esac
	if ! write_record "$_exe" "$_rom"; then
		blocked "$_tag record"
		return 1
	fi
	# Publish only after the record is valid. The session reads it
	# once nextui.elf has exited.
	mv "$STAGE" /tmp/next
	HANDED=1
	kill -TERM "$_ui" 2>/dev/null || true
	if ! wait_pid_gone "$_ui" 15; then
		# NextUI turns SIGTERM into SDL_QUIT and ignores it so a
		# stray signal does not power the handheld off. The session
		# can take the launch record only after this process exits.
		# Stop the verified frontend pid, not the session.
		_now=$(tr '\000' ' ' < "/proc/$_ui/cmdline" 2>/dev/null || true)
		case "$_now" in
			*nextui.elf*) ;;
			*)
				rm -f /tmp/next
				HANDED=0
				blocked "$_tag nextui-identity-changed"
				return 1
				;;
		esac
		log "sigterm ignored; stopping verified nextui $_ui"
		kill -KILL "$_ui" 2>/dev/null || true
		if ! wait_pid_gone "$_ui" 25; then
			rm -f /tmp/next
			HANDED=0
			blocked "$_tag nextui-stayed"
			return 1
		fi
	fi
	if ! wait_name "$_proc" 80; then
		log "drm after miss"
		drm_lines | while IFS= read -r _line; do log "$_line"; done
		log "session_tail"
		tail -n 30 /tmp/nextui-session.txt 2>/dev/null | while IFS= read -r _line; do
			log "$_line"
		done
		if [ -e /run/zlyme/pak-cleanup-failed ]; then
			blocked "$_tag cleanup-125"
			return 1
		fi
		if wait_nextui 20; then
			result "FAIL $_tag process-not-seen"
			HANDED=0
			return 0
		fi
		blocked "$_tag no-process-no-frontend"
		return 1
	fi
	log "process $(pidof "$_proc" | awk '{print $1}') $_proc"
	log "drm during"
	drm_lines | while IFS= read -r _line; do log "$_line"; done
	sleep 3
	if [ -f /tmp/zlyme-ra-ac.cfg ]; then
		log "ra-ac"
		while IFS= read -r _line; do
			log "$_line"
		done < /tmp/zlyme-ra-ac.cfg
	fi
	if [ "$_tag" = gba ] || [ "$_tag" = ra ] || [ "$_tag" = gb ]; then
		log "log-hints"
		for _lf in /tmp/nextui-session.txt /storage/.logs/paks/GBA.log /storage/.logs/paks/GB.log /storage/.logs/paks/RetroArch.log; do
			[ -f "$_lf" ] || continue
			grep -Ei 'udev|joypad|ALSA|EPIPE|underrun|xrun|error|Microsoft X-Box|Miyoo Flip' "$_lf" 2>/dev/null | tail -n 40 | while IFS= read -r _line; do
				case "$_line" in
					*/mnt/sd2/Roms/*) continue ;;
				esac
				log "hint $_lf $_line"
			done
		done
	fi
	if [ "$_tag" = gba ]; then
		log "pipewire=$(tr -d '\n' < /run/zlyme/pipewire/service 2>/dev/null || true)"
		if [ -d /sys/kernel/debug/dri ]; then
			log "debugfs present"
		else
			log "debugfs not mounted"
		fi
		if command -v pw-top >/dev/null 2>&1; then
			pw-top -b -n 1 2>/dev/null | head -n 20 | while IFS= read -r _line; do
				log "pw $_line"
			done
		else
			log "pw-top absent"
		fi
	fi
	if [ "$_tag" = psp ]; then
		log "psp-mounts"
		awk '$5 ~ /ppsspp/ {print}' /proc/self/mountinfo 2>/dev/null | while IFS= read -r _line; do
			log "mount $_line"
		done
	fi
	_ev=$(virt_event || true)
	if [ -z "$_ev" ]; then
		blocked "$_tag no-virtual-event"
		return 1
	fi
	log "chord $_ev"
	if ! chord "$_ev"; then
		blocked "$_tag chord-failed"
		return 1
	fi
	if ! wait_nextui 80; then
		log "chord retry"
		chord "$_ev" || true
		if ! wait_nextui 40; then
			if [ -e /run/zlyme/pak-cleanup-failed ]; then
				blocked "$_tag cleanup-125"
				return 1
			fi
			blocked "$_tag no-return"
			return 1
		fi
	fi
	if ! kill -0 "$_sess" 2>/dev/null; then
		blocked "$_tag session-died"
		return 1
	fi
	log "drm after"
	if ! drm_unexpected ""; then
		blocked "$_tag unexpected-drm-after"
		return 1
	fi
	_nui=$(nextui_pid || true)
	log "nextui=$_nui session=$_sess"
	markers
	if [ -e /run/zlyme/pak-cleanup-failed ] || [ -e /tmp/zlyme-ppsspp-unresolved ]; then
		blocked "$_tag unresolved"
		return 1
	fi
	# A leftover owned bind is a failure of the return, not a kill.
	if awk '$5 ~ /ppsspp|dolphin-emu|flycast/ {found=1} END{exit !found}' /proc/self/mountinfo 2>/dev/null; then
		result "FAIL $_tag leftover-bind"
		HANDED=0
		return 0
	fi
	result "PASS $_tag"
	HANDED=0
	return 0
}

plat=my355
if [ -f /usr/share/zlyme/device.conf ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/device.conf
	plat=${ZLYME_NEXTUI_PLATFORM:-my355}
fi

log "start $(date -u 2>/dev/null || date)"
log "squashfs $(sha256sum /boot/zlyme 2>/dev/null | awk '{print $1}')"
command -v python3 >/dev/null 2>&1 || {
	result "BLOCKED python3-missing"
	exit 1
}

one=$1
shift || true

case "$one" in
	ra)
		handoff ra "/storage/Tools/$plat/RetroArch.pak/launch.sh" "" retroarch
		;;
	gb)
		_rom=$1
		handoff gb "/storage/Emus/$plat/GB.pak/launch.sh" "$_rom" retroarch
		;;
	gba)
		_rom=$1
		handoff gba "/storage/Emus/$plat/GBA.pak/launch.sh" "$_rom" retroarch
		;;
	nds)
		_rom=$1
		handoff nds "/storage/Emus/$plat/NDS.pak/launch.sh" "$_rom" drastic
		;;
	ppsspp-menu)
		handoff ppsspp-menu "/storage/Emus/$plat/PSP.pak/launch.sh" "" PPSSPPSDL
		;;
	psp)
		_rom=$1
		handoff psp "/storage/Emus/$plat/PSP.pak/launch.sh" "$_rom" PPSSPPSDL
		;;
	psp-find)
		_dir="/mnt/sd2/Roms/Sony PlayStation Portable (PSP)"
		_rom=
		if [ -d "$_dir" ]; then
			_rom=$(find "$_dir" -maxdepth 2 -type f \( -iname '*.iso' -o -iname '*.cso' -o -iname '*.pbp' \) 2>/dev/null | head -n 1)
		fi
		if [ -z "${_rom:-}" ]; then
			result "SKIP psp no-sd2-rom"
			exit 0
		fi
		log "psp candidate=1"
		_sum=$(cksum /storage/.config/ppsspp/PSP/SYSTEM/controls.ini 2>/dev/null || true)
		handoff psp "/storage/Emus/$plat/PSP.pak/launch.sh" "$_rom" PPSSPPSDL
		_st=$?
		_sum2=$(cksum /storage/.config/ppsspp/PSP/SYSTEM/controls.ini 2>/dev/null || true)
		if [ "$_sum" = "$_sum2" ]; then
			log "controls.ini unchanged"
		else
			log "controls.ini changed"
		fi
		exit "$_st"
		;;
	files)
		handoff files "/storage/Tools/$plat/Files.pak/launch.sh" "" vtree
		;;
	portmaster)
		_flag=
		_pug=
		for _root in /storage/Roms/.portmaster/PortMaster /mnt/sd2/Roms/.portmaster/PortMaster; do
			if [ -f "$_root/.pugwash-reboot" ]; then
				_flag=1
			fi
			if [ -f "$_root/pugwash" ]; then
				_pug=$_root/pugwash
			fi
		done
		if [ -n "$_flag" ]; then
			result "SKIP portmaster reboot-flag"
			exit 0
		fi
		if [ -z "$_pug" ]; then
			result "SKIP portmaster no-live-tree"
			exit 0
		fi
		_before=$(cksum "$_pug" 2>/dev/null || true)
		handoff portmaster "/storage/Tools/$plat/PortMaster.pak/launch.sh" "" python3
		_st=$?
		_after=$(cksum "$_pug" 2>/dev/null || true)
		if [ "$_before" = "$_after" ]; then
			log "pugwash unchanged"
		else
			log "pugwash changed"
		fi
		exit "$_st"
		;;
	*)
		result "FAIL unknown-test"
		exit 2
		;;
esac
