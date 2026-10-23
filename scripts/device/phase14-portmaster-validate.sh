#!/bin/sh
# SPDX-License-Identifier: MIT
# Opt-in Phase 14 PortMaster validation.
#
# The Tools PAK claims one queue entry and execs the canonical
# PORTS.pak/launch.sh. nextui-session classifies that Tools path as a
# PortMaster launch (launch_is_ports) so real cleanup runs.
#
# No in-session timeout watchdog and no in-session post-observer.
# Exit is MENU+START or the game's own exit. Post-session evidence is
# gathered from SSH with: phase14-portmaster-validate observe
# Cursor advances only via complete (or fail after unresolved cleanup).
set -eu

root_state=${ZLYME_PHASE14_VALIDATE_DIR:-/storage/.config/zlyme/phase14-validate}
inventory_bin=${ZLYME_PHASE14_INVENTORY:-/usr/libexec/zlyme-tests/phase14-portmaster-inventory}
observer_bin=${ZLYME_PHASE14_OBSERVER:-/usr/libexec/zlyme-tests/phase14-port-observer}
ports_launch=${ZLYME_PORTS_LAUNCH:-/usr/share/nextui/paks/Emus/PORTS.pak/launch.sh}
suite_budget=${ZLYME_PHASE14_SUITE_BUDGET:-3600}

die() {
	echo "phase14-validate: $*" >&2
	exit 1
}

stamp() {
	date -u +%Y-%m-%dT%H:%M:%SZ
}

atomic_write() {
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

pid_alive() {
	pid=$1
	case "$pid" in
		''|*[!0-9]*|0|1) return 1 ;;
	esac
	[ -d "/proc/$pid" ] || return 1
	# Zombies are not live owners.
	state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null || echo Z)
	[ "$state" != Z ]
}

# Lock is held for the whole in-flight run. A dead lock owner with no
# active-run may be reclaimed. An active-run without a live claimer is
# left for complete/fail/retry — never silently advanced.
acquire_lock() {
	cdir=$1
	lock=$cdir/lock
	if mkdir "$lock" 2>/dev/null; then
		printf '%s\n' "$$" > "$lock/pid"
		return 0
	fi
	old=
	[ -f "$lock/pid" ] && old=$(tr -d '\r\n' < "$lock/pid")
	if [ -n "$old" ] && pid_alive "$old"; then
		die "campaign lock held by pid $old"
	fi
	# Stale lock directory.
	if [ -f "$cdir/active-run" ]; then
		die "stale lock but active-run present; run observe/complete/fail/retry"
	fi
	rm -f "$lock/pid"
	rmdir "$lock" 2>/dev/null || die "could not reclaim stale lock"
	mkdir "$lock" || die "could not acquire lock after reclaim"
	printf '%s\n' "$$" > "$lock/pid"
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
		printf 'suite_budget_secs=%s\n' "$suite_budget"
		printf 'exit_policy=MENU+START_or_game_exit\n'
		printf 'observe=phase14-portmaster-validate observe\n'
	} | atomic_write "$cdir/meta.txt"
	[ -x "$inventory_bin" ] || die "inventory helper missing"
	"$inventory_bin" "$cdir"
	[ -s "$cdir/queue.txt" ] || die "inventory produced an empty queue"
	printf '0\n' | atomic_write "$cdir/cursor"
	date +%s | atomic_write "$cdir/suite-started"
	printf '%s\n' "$cid" | atomic_write "$root_state/active-campaign"
	echo "phase14-validate started campaign $cid (gpu=$gpu)"
	echo "phase14-validate: no automated kill timer; use MENU+START and SSH observe"
}

cmd_reset() {
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
		if [ -f "$cdir/active-run" ]; then
			echo "active_run=yes"
			cat "$cdir/active-run"
		else
			echo "active_run=no"
		fi
	else
		echo "active="
	fi
}

# Peek the next ELIGIBLE row at or after cursor without advancing.
peek_eligible() {
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
		n=$((n + 1))
		if [ "$ready" != ELIGIBLE ]; then
			printf 'SKIP ready=%s id=%s script=%s\n' "$ready" "$id" "$script" >&2
			printf '%s\t%s\t%s\t%s\n' "$(stamp)" "$ready" "$id" "$script" >> "$cdir/skipped.log"
			# Skip non-eligible immediately; that is not a launched test.
			printf '%s\n' "$n" | atomic_write "$cursor"
			idx=$n
			continue
		fi
		[ -f "$script" ] || die "queue script missing: $script"
		# Emit: queue_index(after claim) id script
		printf '%s\t%s\t%s\n' "$n" "$id" "$script"
		return 0
	done < "$queue"
	return 1
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

verify_campaign_identity() {
	cdir=$1
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
}

# Claim one game into active-run. Cursor advances only on complete/fail.
cmd_run() {
	cdir=$(campaign_dir)
	[ -f "$cdir/meta.txt" ] || die "campaign meta missing"
	[ -f "$cdir/blocked" ] && die "campaign blocked: $(cat "$cdir/blocked")"
	verify_campaign_identity "$cdir"

	if [ -f "$cdir/active-run" ]; then
		die "active-run already set; observe/complete/fail/retry before another launch"
	fi

	acquire_lock "$cdir"
	# Lock stays until complete/fail/retry. Survives exec as a directory.
	# Do not trap-release on EXIT: exec replaces us; SSH complete clears it.

	row=$(peek_eligible "$cdir") || {
		release_lock "$cdir"
		die "no further ELIGIBLE ports in queue"
	}
	next_idx=${row%%	*}
	rest=${row#*	}
	id=${rest%%	*}
	script=${rest#*	}
	meta_gpu=$(awk -F= '/^gpu=/{print $2; exit}' "$cdir/meta.txt")
	run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
	run_log=$cdir/runs/${id}-${meta_gpu}-${run_stamp}.log
	ports=$(find_ports_launch) || {
		release_lock "$cdir"
		die "PORTS.pak/launch.sh not found"
	}

	{
		printf 'status=in_flight\n'
		printf 'claimed=%s\n' "$(stamp)"
		printf 'queue_next_index=%s\n' "$next_idx"
		printf 'id=%s\n' "$id"
		printf 'script=%s\n' "$script"
		printf 'run_log=%s\n' "$run_log"
		printf 'ports_launch=%s\n' "$ports"
		printf 'claimer_pid=%s\n' "$$"
		printf 'gpu=%s\n' "$meta_gpu"
		printf 'campaign=%s\n' "$(active_campaign)"
	} | atomic_write "$cdir/active-run"

	{
		echo "PHASE14_VALIDATE format=3"
		echo "START time=$(stamp) campaign=$(active_campaign) id=$id gpu=$meta_gpu"
		echo "SCRIPT $script"
		echo "PORTS_LAUNCH $ports"
		echo "CLAIMER pid=$$"
		echo "NOTE no automated timeout; use MENU+START or natural exit"
		echo "NOTE cursor advances only via complete/fail after observe"
		echo "NOTE post-session evidence: phase14-portmaster-validate observe"
	} | atomic_write "$run_log"

	if [ -r /sys/kernel/debug/dri/0/clients ]; then
		others=$(awk 'NR>1 && $2 ~ /^[0-9]+$/ {print $2}' /sys/kernel/debug/dri/0/clients | tr '\n' ' ')
		for p in $others; do
			[ "$p" = "$$" ] && continue
			cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || true)
			case "$cmd" in
				*nextui.elf* | '') ;;
				*)
					echo "DRM_PRECHECK foreign_pid=$p cmd=$cmd" >> "$run_log"
					printf 'unresolved DRM client pid %s before launch\n' "$p" | atomic_write "$cdir/blocked"
					# Keep active-run for retry; release lock so fail/retry can run.
					release_lock "$cdir"
					die "foreign DRM client $p still active; campaign blocked"
					;;
			esac
		done
	fi

	echo "phase14-validate exec PORTS.pak for $id (lock held; complete after observe)" >&2
	# No command substitutions that start background jobs. Exec promptly.
	exec "$ports" "$script"
}

append_observe() {
	run_log=$1
	{
		echo "OBSERVE time=$(stamp)"
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
		echo "NOTE visible frontend and audio/input require physical observation"
	} >> "$run_log"
}

# SSH-side, after the PAK session has ended.
cmd_observe() {
	cdir=$(campaign_dir)
	[ -f "$cdir/active-run" ] || die "no active-run to observe"
	run_log=$(awk -F= '/^run_log=/{print $2; exit}' "$cdir/active-run")
	[ -n "$run_log" ] || die "active-run missing run_log"
	append_observe "$run_log"
	if [ -x "$observer_bin" ]; then
		duration=${1:-30}
		"$observer_bin" "$duration" 2 >> "${run_log%.log}.ssh-observer.log" 2>&1 || true
	fi
	echo "phase14-validate observe wrote $run_log"
}

advance_past_active() {
	cdir=$1
	next_idx=$(awk -F= '/^queue_next_index=/{print $2; exit}' "$cdir/active-run")
	case "$next_idx" in
		''|*[!0-9]*) die "active-run missing queue_next_index" ;;
	esac
	printf '%s\n' "$next_idx" | atomic_write "$cdir/cursor"
}

# Successful or accepted physical result: advance queue, clear in-flight.
cmd_complete() {
	cdir=$(campaign_dir)
	[ -f "$cdir/active-run" ] || die "no active-run to complete"
	run_log=$(awk -F= '/^run_log=/{print $2; exit}' "$cdir/active-run")
	result=${1:-PASS_PROCESS}
	{
		echo "COMPLETE time=$(stamp) result=$result"
		echo "NOTE result=$result is not a render/input/MENU+START PASS by itself"
	} >> "$run_log"
	advance_past_active "$cdir"
	mv -f "$cdir/active-run" "$cdir/runs/completed-$(date -u +%Y%m%dT%H%M%SZ).active-run"
	release_lock "$cdir"
	rm -f "$cdir/blocked"
	echo "phase14-validate complete result=$result cursor=$(cat "$cdir/cursor")"
}

# Unresolved cleanup or blocked: do not advance; keep identity for retry.
cmd_fail() {
	cdir=$(campaign_dir)
	[ -f "$cdir/active-run" ] || die "no active-run to fail"
	run_log=$(awk -F= '/^run_log=/{print $2; exit}' "$cdir/active-run")
	reason=${1:-unresolved}
	{
		echo "FAIL time=$(stamp) reason=$reason"
		echo "NOTE cursor not advanced; use retry after fixing"
	} >> "$run_log"
	printf '%s\n' "$reason" | atomic_write "$cdir/blocked"
	# Keep active-run and evidence; release lock so retry can reclaim.
	release_lock "$cdir"
	echo "phase14-validate fail: $reason (active-run retained for retry)"
}

# Clear a failed/in-flight claim without advancing; same game relaunches.
cmd_retry() {
	cdir=$(campaign_dir)
	if [ -f "$cdir/active-run" ]; then
		run_log=$(awk -F= '/^run_log=/{print $2; exit}' "$cdir/active-run")
		[ -n "$run_log" ] && echo "RETRY time=$(stamp)" >> "$run_log"
		mv -f "$cdir/active-run" "$cdir/runs/retried-$(date -u +%Y%m%dT%H%M%SZ).active-run"
	fi
	rm -f "$cdir/blocked"
	release_lock "$cdir"
	echo "phase14-validate retry: same cursor $(cat "$cdir/cursor"); active-run cleared"
}

case "${1:-run}" in
start) cmd_start ;;
reset) cmd_reset ;;
status) cmd_status ;;
run|"") cmd_run ;;
observe) shift; cmd_observe "${1:-30}" ;;
complete) shift; cmd_complete "${1:-PASS_PROCESS}" ;;
fail) shift; cmd_fail "${1:-unresolved}" ;;
retry) cmd_retry ;;
inventory)
	cdir=$(campaign_dir)
	[ -x "$inventory_bin" ] || die "inventory missing"
	exec "$inventory_bin" "$cdir"
	;;
*)
	die "usage: $0 {start|run|observe|complete|fail|retry|reset|status|inventory}"
	;;
esac
