#!/bin/sh
# SPDX-License-Identifier: MIT
# Opt-in Phase 14 PortMaster validation.
#
# The Tools PAK only selects the next ROM and execs the canonical
# PORTS.pak/launch.sh. nextui-session classifies that Tools path as a
# PortMaster launch (launch_is_ports) so the real cleanup runs. This
# script does not duplicate port bind/prepare/drm-release.
set -eu

root_state=${ZLYME_PHASE14_VALIDATE_DIR:-/storage/.config/zlyme/phase14-validate}
inventory_bin=${ZLYME_PHASE14_INVENTORY:-/usr/libexec/zlyme-tests/phase14-portmaster-inventory}
observer_bin=${ZLYME_PHASE14_OBSERVER:-/usr/libexec/zlyme-tests/phase14-port-observer}
ports_launch=${ZLYME_PORTS_LAUNCH:-/usr/share/nextui/paks/Emus/PORTS.pak/launch.sh}
max_secs=${ZLYME_PHASE14_PORT_TIMEOUT:-180}
suite_budget=${ZLYME_PHASE14_SUITE_BUDGET:-3600}

die() {
	echo "phase14-validate: $*" >&2
	exit 1
}

stamp() {
	date -u +%Y-%m-%dT%H:%M:%SZ
}

atomic_write() {
	# $1 dest, stdin content
	dest=$1
	tmp=$dest.tmp.$$
	cat > "$tmp"
	mv -f "$tmp" "$dest"
}

gpu_name() {
	if [ -n "${ZLYME_PHASE14_TEST_GPU:-}" ]; then
		printf '%s\n' "$ZLYME_PHASE14_TEST_GPU"
		return 0
	fi
	if [ -r /storage/.config/zlyme/gpu ]; then
		tr -d '\r\n' < /storage/.config/zlyme/gpu
	else
		echo unknown
	fi
}

squashfs_id() {
	if [ -n "${ZLYME_PHASE14_TEST_SQUASHFS:-}" ]; then
		printf '%s\n' "$ZLYME_PHASE14_TEST_SQUASHFS"
		return 0
	fi
	if [ -r /boot/zlyme ]; then
		sha256sum /boot/zlyme | awk '{print $1}'
	else
		echo unknown
	fi
}

boot_id() {
	if [ -n "${ZLYME_PHASE14_TEST_BOOT_ID:-}" ]; then
		printf '%s\n' "$ZLYME_PHASE14_TEST_BOOT_ID"
		return 0
	fi
	tr -d '\r\n' < /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown
}

library_id() {
	if [ -r /run/zlyme/libraries ]; then
		tr '\n' ' ' < /run/zlyme/libraries | sed 's/[[:space:]]*$//'
	else
		echo unknown
	fi
}

active_campaign() {
	if [ -n "${ZLYME_PHASE14_CAMPAIGN:-}" ]; then
		printf '%s\n' "$ZLYME_PHASE14_CAMPAIGN"
		return 0
	fi
	if [ -f "$root_state/active-campaign" ]; then
		tr -d '\r\n' < "$root_state/active-campaign"
		return 0
	fi
	return 1
}

campaign_dir() {
	id=$(active_campaign) || die "no active campaign; run: phase14-portmaster-validate start"
	printf '%s\n' "$root_state/campaigns/$id"
}

acquire_lock() {
	cdir=$1
	lock=$cdir/lock
	if mkdir "$lock" 2>/dev/null; then
		printf '%s\n' "$$" > "$lock/pid"
		return 0
	fi
	die "campaign lock held (another validation runner owns this queue)"
}

release_lock() {
	cdir=$1
	lock=$cdir/lock
	[ -d "$lock" ] || return 0
	rm -f "$lock/pid"
	rmdir "$lock" 2>/dev/null || true
}

cmd_start() {
	mkdir -p "$root_state/campaigns"
	gpu=$(gpu_name)
	sq=$(squashfs_id)
	bid=$(boot_id)
	lib=$(library_id)
	cid=$(date -u +%Y%m%dT%H%M%SZ)-$gpu-$(printf '%s' "$bid" | cut -c1-8)
	cdir=$root_state/campaigns/$cid
	mkdir -p "$cdir/runs"
	{
		printf 'campaign_id=%s\n' "$cid"
		printf 'created=%s\n' "$(stamp)"
		printf 'gpu=%s\n' "$gpu"
		printf 'squashfs_sha256=%s\n' "$sq"
		printf 'boot_id=%s\n' "$bid"
		printf 'libraries=%s\n' "$lib"
		printf 'timeout_secs=%s\n' "$max_secs"
		printf 'suite_budget_secs=%s\n' "$suite_budget"
	} | atomic_write "$cdir/meta.txt"
	[ -x "$inventory_bin" ] || die "inventory helper missing"
	"$inventory_bin" "$cdir"
	[ -s "$cdir/queue.txt" ] || die "inventory produced an empty queue"
	printf '0\n' | atomic_write "$cdir/cursor"
	date +%s | atomic_write "$cdir/suite-started"
	printf '%s\n' "$cid" | atomic_write "$root_state/active-campaign"
	echo "phase14-validate started campaign $cid (gpu=$gpu)"
}

cmd_reset() {
	# Drop active pointer and suite budget. Keep campaign reports.
	rm -f "$root_state/active-campaign"
	echo "phase14-validate reset: no active campaign (prior reports retained under $root_state/campaigns)"
}

cmd_status() {
	if id=$(active_campaign 2>/dev/null); then
		cdir=$root_state/campaigns/$id
		echo "active=$id"
		[ -f "$cdir/meta.txt" ] && cat "$cdir/meta.txt"
		[ -f "$cdir/cursor" ] && echo "cursor=$(cat "$cdir/cursor")"
		[ -f "$cdir/blocked" ] && echo "blocked=$(cat "$cdir/blocked")"
	else
		echo "active="
	fi
}

next_eligible() {
	cdir=$1
	queue=$cdir/queue.txt
	cursor=$cdir/cursor
	idx=$(tr -d '\r\n' < "$cursor")
	case "$idx" in
		''|*[!0-9]*) die "corrupt cursor in $cursor" ;;
	esac
	n=0
	while IFS="$(printf '\t')" read -r ready id script; do
		[ -n "${ready:-}" ] || continue
		if [ "$n" -lt "$idx" ]; then
			n=$((n + 1))
			continue
		fi
		# Advance past this row whether eligible or not.
		n=$((n + 1))
		printf '%s\n' "$n" | atomic_write "$cursor"
		if [ "$ready" != ELIGIBLE ]; then
			printf 'SKIP ready=%s id=%s script=%s\n' "$ready" "$id" "$script" >&2
			printf '%s\t%s\t%s\t%s\n' "$(stamp)" "$ready" "$id" "$script" >> "$cdir/skipped.log"
			continue
		fi
		[ -f "$script" ] || die "queue script missing: $script"
		printf '%s\t%s\n' "$id" "$script"
		return 0
	done < "$queue"
	return 1
}

arm_timeout_waiter() {
	# Signal the pak-spawn waiter (session leader's PPID), not a
	# historical game PID. The waiter owns stop_session_bounded.
	waiter_pid=$1
	run_log=$2
	(
		sleep "$max_secs"
		{
			echo "TIMEOUT time=$(stamp) waiter=$waiter_pid"
			if [ -r "/proc/$waiter_pid/stat" ]; then
				printf 'TIMEOUT_WAITER_STAT '
				cat "/proc/$waiter_pid/stat"
			else
				echo "TIMEOUT_WAITER gone"
			fi
		} >> "$run_log"
		kill -TERM "$waiter_pid" 2>/dev/null || true
	) &
	printf '%s\n' "$!"
}

start_post_observer() {
	run_log=$1
	leader_pid=$2
	(
		# Survive the Tools shell's exec into PORTS.pak.
		i=0
		while [ "$i" -lt 600 ]; do
			if [ ! -d "/proc/$leader_pid" ]; then
				break
			fi
			# Leader may be zombie briefly.
			state=$(awk '{print $3}' "/proc/$leader_pid/stat" 2>/dev/null || echo X)
			if [ "$state" = Z ]; then
				break
			fi
			sleep 1
			i=$((i + 1))
		done
		# Bound: allow cleanup + frontend restore.
		sleep 2
		{
			echo "POST_OBSERVE time=$(stamp) after_leader=$leader_pid"
			if pidof nextui.elf >/dev/null 2>&1; then
				echo "NEXTUI_RESTORED process=yes"
			else
				echo "NEXTUI_RESTORED process=no"
			fi
			if [ -r /sys/kernel/debug/dri/0/clients ]; then
				awk '{ print "DRM_CLIENT " $0 }' /sys/kernel/debug/dri/0/clients
			else
				echo "DRM_CLIENTS unavailable"
			fi
			if [ -r /run/zlyme-portmaster/owned-mounts ] &&
				[ -s /run/zlyme-portmaster/owned-mounts ]; then
				echo "OWNED_MOUNTS_REMAIN begin"
				cat /run/zlyme-portmaster/owned-mounts
				echo "OWNED_MOUNTS_REMAIN end"
			else
				echo "OWNED_MOUNTS_REMAIN none"
			fi
			echo "NOTE visible frontend requires physical observation"
		} >> "$run_log"
		if [ -x "$observer_bin" ]; then
			"$observer_bin" 15 2 >> "${run_log%.log}.post-observer.log" 2>&1 || true
		fi
	) &
	printf '%s\n' "$!"
}

find_ports_launch() {
	if [ -x "$ports_launch" ]; then
		printf '%s\n' "$ports_launch"
		return 0
	fi
	for cand in \
		/usr/share/nextui/paks/Emus/PORTS.pak/launch.sh \
		/storage/Emus/PORTS.pak/launch.sh \
		/mnt/sd2/Emus/PORTS.pak/launch.sh
	do
		if [ -x "$cand" ]; then
			printf '%s\n' "$cand"
			return 0
		fi
	done
	return 1
}

# Called as the Tools PAK body: select one ROM, arm helpers, exec PORTS.pak.
cmd_run() {
	cdir=$(campaign_dir)
	[ -f "$cdir/meta.txt" ] || die "campaign meta missing"
	[ -f "$cdir/blocked" ] && die "campaign blocked: $(cat "$cdir/blocked")"

	# Reject stale queue paths from another boot/library/gpu.
	meta_gpu=$(awk -F= '/^gpu=/{print $2; exit}' "$cdir/meta.txt")
	meta_boot=$(awk -F= '/^boot_id=/{print $2; exit}' "$cdir/meta.txt")
	meta_sq=$(awk -F= '/^squashfs_sha256=/{print $2; exit}' "$cdir/meta.txt")
	cur_gpu=$(gpu_name)
	cur_boot=$(boot_id)
	cur_sq=$(squashfs_id)
	[ "$meta_gpu" = "$cur_gpu" ] || die "campaign gpu $meta_gpu != current $cur_gpu; start a new campaign"
	[ "$meta_boot" = "$cur_boot" ] || die "campaign boot_id changed; start a new campaign"
	[ "$meta_sq" = "$cur_sq" ] || die "campaign squashfs changed; start a new campaign"

	now=$(date +%s)
	suite_start=$(tr -d '\r\n' < "$cdir/suite-started")
	if [ $((now - suite_start)) -ge "$suite_budget" ]; then
		die "suite budget ${suite_budget}s exhausted; reset and start"
	fi

	acquire_lock "$cdir"
	# shellcheck disable=SC2064
	trap "release_lock \"$cdir\"" EXIT

	pair=$(next_eligible "$cdir") || die "no further ELIGIBLE ports in queue"
	id=${pair%%	*}
	script=${pair#*	}
	run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
	run_log=$cdir/runs/${id}-${meta_gpu}-${run_stamp}.log

	ports=$(find_ports_launch) || die "PORTS.pak/launch.sh not found"

	waiter_pid=$PPID
	leader_pid=$$

	{
		echo "PHASE14_VALIDATE format=2"
		echo "START time=$(stamp) campaign=$(active_campaign) id=$id gpu=$meta_gpu"
		echo "SCRIPT $script"
		echo "PORTS_LAUNCH $ports"
		echo "LEADER pid=$leader_pid"
		echo "WAITER pid=$waiter_pid"
		echo "TIMEOUT_SECS $max_secs"
		echo "NOTE game exit/render/input/MENU+START are independent results"
	} | atomic_write "$run_log"

	# Live DRM owner check before launching.
	if [ -r /sys/kernel/debug/dri/0/clients ]; then
		others=$(awk 'NR>1 && $2 ~ /^[0-9]+$/ {print $2}' /sys/kernel/debug/dri/0/clients | tr '\n' ' ')
		# nextui.elf should have released; warn if foreign masters linger.
		for p in $others; do
			[ "$p" = "$leader_pid" ] && continue
			cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || true)
			case "$cmd" in
				*nextui.elf* | '') ;;
				*)
					echo "DRM_PRECHECK foreign_pid=$p cmd=$cmd" >> "$run_log"
					printf 'unresolved DRM client pid %s before launch\n' "$p" > "$cdir/blocked"
					die "foreign DRM client $p still active; campaign blocked"
					;;
			esac
		done
	fi

	timer_pid=$(arm_timeout_waiter "$waiter_pid" "$run_log")
	post_pid=$(start_post_observer "$run_log" "$leader_pid")
	echo "TIMER_PID $timer_pid" >> "$run_log"
	echo "POST_OBSERVER_PID $post_pid" >> "$run_log"

	# Release lock before exec so a later Tools launch can proceed after
	# this session ends. The blocked flag still stops the campaign.
	release_lock "$cdir"
	trap - EXIT

	echo "phase14-validate exec PORTS.pak for $id" >&2
	exec "$ports" "$script"
}

cmd_retry() {
	# Rewind cursor by one and clear blocked, for a failed game retry.
	cdir=$(campaign_dir)
	[ -f "$cdir/cursor" ] || die "no cursor"
	idx=$(tr -d '\r\n' < "$cdir/cursor")
	case "$idx" in
		''|*[!0-9]*) die "corrupt cursor" ;;
	esac
	if [ "$idx" -gt 0 ]; then
		printf '%s\n' $((idx - 1)) | atomic_write "$cdir/cursor"
	fi
	rm -f "$cdir/blocked"
	echo "phase14-validate retry: cursor=$idx -> $(cat "$cdir/cursor")"
}

case "${1:-run}" in
start) cmd_start ;;
reset) cmd_reset ;;
status) cmd_status ;;
retry) cmd_retry ;;
inventory)
	cdir=$(campaign_dir)
	[ -x "$inventory_bin" ] || die "inventory missing"
	exec "$inventory_bin" "$cdir"
	;;
run|"") cmd_run ;;
*)
	die "usage: $0 {start|run|reset|retry|status|inventory}"
	;;
esac
