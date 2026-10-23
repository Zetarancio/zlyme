#!/bin/sh
# SPDX-License-Identifier: MIT
# Opt-in Phase 14 PortMaster validation: one eligible port per launch.
# Reuses PORTS.pak ownership (prepare, bind, drm-release, real script).
# Does not synthesize MENU+START. A bounded timeout signals only the
# recorded session leader so pak-spawn can reap members.
set -eu

state_dir=${ZLYME_PHASE14_VALIDATE_DIR:-/storage/.config/zlyme/phase14-validate}
queue=$state_dir/queue.txt
cursor=$state_dir/cursor
max_secs=${ZLYME_PHASE14_PORT_TIMEOUT:-180}
suite_budget=${ZLYME_PHASE14_SUITE_BUDGET:-3600}
observer=${ZLYME_PHASE14_OBSERVER:-/usr/libexec/zlyme-tests/phase14-port-observer}
inventory=${ZLYME_PHASE14_INVENTORY:-/usr/libexec/zlyme-tests/phase14-portmaster-inventory}

die() {
	echo "phase14-validate: $*" >&2
	exit 1
}

stamp() {
	date -u +%Y-%m-%dT%H:%M:%SZ
}

gpu_name() {
	if [ -r /storage/.config/zlyme/gpu ]; then
		tr -d '\r\n' < /storage/.config/zlyme/gpu
	else
		echo unknown
	fi
}

ensure_queue() {
	if [ ! -s "$queue" ]; then
		[ -x "$inventory" ] || die "inventory helper missing: $inventory"
		"$inventory" "$state_dir"
	fi
	[ -s "$queue" ] || die "empty validation queue"
	[ -f "$cursor" ] || echo 0 > "$cursor"
}

next_eligible() {
	idx=$(cat "$cursor")
	n=0
	while IFS="$(printf '\t')" read -r ready id script; do
		[ -n "${ready:-}" ] || continue
		if [ "$n" -lt "$idx" ]; then
			n=$((n + 1))
			continue
		fi
		n=$((n + 1))
		echo $((n)) > "$cursor"
		if [ "$ready" != ELIGIBLE ]; then
			printf 'SKIP ready=%s id=%s script=%s\n' "$ready" "$id" "$script" >&2
			continue
		fi
		printf '%s\t%s\n' "$id" "$script"
		return 0
	done < "$queue"
	return 1
}

run_ports_like() {
	ROM=$1
	[ -r /usr/share/zlyme/pak-input.sh ] && . /usr/share/zlyme/pak-input.sh
	if [ -r /usr/share/nextui/bin/zlyme-library.sh ]; then
		# shellcheck disable=SC1091
		. /usr/share/nextui/bin/zlyme-library.sh
		zlyme_ports_bind "$ROM"
		trap zlyme_ports_unbind EXIT
	fi
	export CFW_NAME=Zlyme
	export DEVICE_NAME="${DEVICE_NAME:-Miyoo Flip}"
	if [ -x /usr/sbin/zlyme-portmaster-prepare ]; then
		/usr/sbin/zlyme-portmaster-prepare || return 1
		eval "$(/usr/sbin/zlyme-portmaster-root export)" || {
			echo "PortMaster disk is not inserted" >&2
			return 1
		}
		export HM_TOOLS_DIR HM_PORTS_DIR HM_SCRIPTS_DIR
	fi
	command -v zlyme-drm-release >/dev/null 2>&1 && zlyme-drm-release >/dev/null 2>&1 || true
	command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor emu PORTS >/dev/null 2>&1 || true
	command -v zlyme-bcsh >/dev/null 2>&1 && zlyme-bcsh >/dev/null 2>&1 || true
	case "$ROM" in
		*.sh)
			if command -v bash >/dev/null 2>&1; then
				bash "$ROM"
				return $?
			fi
			sh "$ROM"
			return $?
			;;
		*)
			"$ROM"
			return $?
			;;
	esac
}

post_checks() {
	log=$1
	{
		echo "POST time=$(stamp)"
		if pidof nextui.elf >/dev/null 2>&1; then
			echo "NEXTUI running=yes"
		else
			echo "NEXTUI running=no"
		fi
		if [ -r /sys/kernel/debug/dri/0/clients ]; then
			awk '{ print "DRM_CLIENT " $0 }' /sys/kernel/debug/dri/0/clients
		else
			echo "DRM_CLIENTS unavailable"
		fi
		if [ -r /run/zlyme-portmaster/owned-mounts ]; then
			echo "OWNED_MOUNTS begin"
			cat /run/zlyme-portmaster/owned-mounts
			echo "OWNED_MOUNTS end"
		else
			echo "OWNED_MOUNTS none"
		fi
	} >> "$log"
}

case "${1:-run}" in
inventory)
	[ -x "$inventory" ] || die "inventory helper missing"
	exec "$inventory" "$state_dir"
	;;
reset)
	rm -f "$cursor"
	echo "phase14-validate cursor reset"
	;;
run|"" )
	mkdir -p "$state_dir/runs"
	ensure_queue
	started_suite=$state_dir/suite-started
	if [ ! -f "$started_suite" ]; then
		date +%s > "$started_suite"
	fi
	now=$(date +%s)
	suite_start=$(cat "$started_suite")
	if [ $((now - suite_start)) -ge "$suite_budget" ]; then
		die "suite budget ${suite_budget}s exhausted; reset or raise ZLYME_PHASE14_SUITE_BUDGET"
	fi

	pair=$(next_eligible) || die "no further ELIGIBLE ports in queue"
	id=${pair%%	*}
	script=${pair#*	}
	gpu=$(gpu_name)
	run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
	run_log=$state_dir/runs/${id}-${gpu}-${run_stamp}.log
	obs_log=$state_dir/runs/${id}-${gpu}-${run_stamp}.observer.log

	{
		echo "PHASE14_VALIDATE format=1"
		echo "START time=$(stamp) id=$id gpu=$gpu script=$script timeout=$max_secs"
		echo "LEADER pid=$$ ppid=$PPID"
		printf 'LEADER '
		# BusyBox-friendly identity snapshot.
		if [ -r /proc/$$/stat ]; then
			cat /proc/$$/stat
		fi
	} > "$run_log"

	if [ -x "$observer" ]; then
		"$observer" "$max_secs" 2 >"$obs_log" 2>&1 &
		obs_pid=$!
	else
		obs_pid=
		echo "OBSERVER missing" >> "$run_log"
	fi

	leader=$$
	(
		sleep "$max_secs"
		echo "TIMEOUT time=$(stamp) signaling leader=$leader" >> "$run_log"
		kill -TERM "$leader" 2>/dev/null || true
	) &
	timer=$!

	set +e
	run_ports_like "$script"
	rc=$?
	set -e

	kill "$timer" 2>/dev/null || true
	wait "$timer" 2>/dev/null || true
	if [ -n "$obs_pid" ]; then
		kill "$obs_pid" 2>/dev/null || true
		wait "$obs_pid" 2>/dev/null || true
	fi

	{
		echo "END time=$(stamp) exit=$rc"
		echo "NOTE render/input/audio/MENU+START require physical observation"
		echo "NOTE exit=$rc alone is not PASS"
	} >> "$run_log"
	post_checks "$run_log"
	echo "phase14-validate wrote $run_log (exit $rc)"
	exit "$rc"
	;;
*)
	die "usage: $0 [inventory|reset|run]"
	;;
esac
