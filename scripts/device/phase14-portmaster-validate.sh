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
#
# complete advances the cursor only after the claimer process identity
# has ended and machine-proven cleanup evidence is present. A user
# label (PASS_PROCESS) is never treated as that proof.
set -eu

root_state=${ZLYME_PHASE14_VALIDATE_DIR:-/storage/.config/zlyme/phase14-validate}
inventory_bin=${ZLYME_PHASE14_INVENTORY:-/usr/libexec/zlyme-tests/phase14-portmaster-inventory}
observer_bin=${ZLYME_PHASE14_OBSERVER:-/usr/libexec/zlyme-tests/phase14-port-observer}
ports_launch=${ZLYME_PORTS_LAUNCH:-/usr/share/nextui/paks/Emus/PORTS.pak/launch.sh}
suite_budget=${ZLYME_PHASE14_SUITE_BUDGET:-3600}
owned_mounts_path=${ZLYME_PHASE14_OWNED_MOUNTS:-/run/zlyme-portmaster/owned-mounts}
drm_clients_path=${ZLYME_PHASE14_DRM_CLIENTS:-/sys/kernel/debug/dri/0/clients}
pak_cleanup_failed_path=${ZLYME_PHASE14_PAK_CLEANUP_FAILED:-/run/zlyme/pak-cleanup-failed}

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
	if [ -n "${ZLYME_PHASE14_TEST_LIBRARIES:-}" ]; then
		printf '%s\n' "$ZLYME_PHASE14_TEST_LIBRARIES"
		return 0
	fi
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

# starttime from /proc/<pid>/stat (field 22). Fail closed on parse error.
proc_starttime() {
	pid=$1
	[ -r "/proc/$pid/stat" ] || return 1
	# After "pid (comm)" the 20th token is starttime.
	line=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
	rest=${line#*)}
	# shellcheck disable=SC2086
	set -- $rest
	# BusyBox ash treats $20 as ${2}0; always use ${20}.
	[ "$#" -ge 20 ] || return 1
	st=${20}
	case "$st" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '%s\n' "$st"
}

# Live non-zombie process whose starttime matches the recorded value.
# Unreadable /proc or mismatched identity is not "safe to reclaim".
pid_identity_live() {
	pid=$1
	want=$2
	case "$pid" in
		''|*[!0-9]*|0|1) return 1 ;;
	esac
	case "$want" in
		''|*[!0-9]*) return 1 ;;
	esac
	[ -d "/proc/$pid" ] || return 1
	# Parse state after "pid (comm)" — awk $3 breaks when comm has spaces.
	# Do not use a bare ? in case: it is a one-character glob.
	line=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
	rest=${line#*)}
	# shellcheck disable=SC2086
	set -- $rest
	state=${1:-UNKNOWN}
	case "$state" in
		Z|UNKNOWN) return 1 ;;
	esac
	have=$(proc_starttime "$pid") || return 1
	[ "$have" = "$want" ]
}

# Ambiguous ownership: pid present but starttime unreadable/mismatched
# while the directory still exists — not safe to treat as dead.
pid_identity_ambiguous() {
	pid=$1
	want=$2
	case "$pid" in
		''|*[!0-9]*|0|1) return 1 ;;
	esac
	[ -d "/proc/$pid" ] || return 1
	line=$(cat "/proc/$pid/stat" 2>/dev/null) || return 0
	rest=${line#*)}
	# shellcheck disable=SC2086
	set -- $rest
	state=${1:-UNKNOWN}
	[ "$state" != Z ] || return 1
	have=$(proc_starttime "$pid") || return 0
	[ "$have" != "$want" ]
}

active_run_get() {
	key=$1
	file=$2
	awk -F= -v k="$key" '$1 == k { print substr($0, index($0, "=") + 1); exit }' "$file"
}

claimer_still_active() {
	ar=$1
	pid=$(active_run_get claimer_pid "$ar")
	st=$(active_run_get claimer_starttime "$ar")
	if pid_identity_live "$pid" "$st"; then
		return 0
	fi
	if pid_identity_ambiguous "$pid" "$st"; then
		die "claimer pid $pid identity ambiguous; refuse transition"
	fi
	return 1
}

# Print campaign ids that still have active-run. Exit 0 if any exist.
list_unresolved_campaigns() {
	found=0
	for ar in "$root_state"/campaigns/*/active-run; do
		[ -f "$ar" ] || continue
		found=1
		basename "$(dirname "$ar")"
	done
	[ "$found" -eq 1 ]
}

refuse_unresolved() {
	op=$1
	list=$(list_unresolved_campaigns | tr '\n' ' ') || true
	case "$list" in
		'') return 0 ;;
	esac
	die "$op refused: unresolved active-run in: $list"
}

# Lock owner is pid + starttime. Never reclaim on ambiguous identity.
acquire_lock() {
	cdir=$1
	lock=$cdir/lock
	my_st=$(proc_starttime "$$") || die "cannot read own starttime"
	if mkdir "$lock" 2>/dev/null; then
		{
			printf 'pid=%s\n' "$$"
			printf 'starttime=%s\n' "$my_st"
		} | atomic_write "$lock/owner"
		return 0
	fi
	old_pid=
	old_st=
	if [ -f "$lock/owner" ]; then
		old_pid=$(active_run_get pid "$lock/owner")
		old_st=$(active_run_get starttime "$lock/owner")
	elif [ -f "$lock/pid" ]; then
		# Pre-format-4 lock: numeric pid only — never treat as safe reclaim.
		die "legacy lock without starttime; refuse reclaim (observe/complete/fail/retry)"
	fi
	if pid_identity_live "$old_pid" "$old_st"; then
		die "campaign lock held by pid $old_pid starttime $old_st"
	fi
	if pid_identity_ambiguous "$old_pid" "$old_st"; then
		die "campaign lock owner identity ambiguous; refuse reclaim"
	fi
	if [ -f "$cdir/active-run" ]; then
		die "stale lock but active-run present; run observe/complete/fail/retry"
	fi
	rm -f "$lock/owner" "$lock/pid"
	rmdir "$lock" 2>/dev/null || die "could not reclaim stale lock"
	mkdir "$lock" || die "could not acquire lock after reclaim"
	{
		printf 'pid=%s\n' "$$"
		printf 'starttime=%s\n' "$my_st"
	} | atomic_write "$lock/owner"
}

release_lock() {
	cdir=$1
	lock=$cdir/lock
	[ -d "$lock" ] || return 0
	rm -f "$lock/owner" "$lock/pid"
	rmdir "$lock" 2>/dev/null || true
}

require_claimer_ended() {
	op=$1
	cdir=$2
	ar=$cdir/active-run
	[ -f "$ar" ] || die "no active-run"
	if claimer_still_active "$ar"; then
		pid=$(active_run_get claimer_pid "$ar")
		die "$op refused: claimer pid $pid still active (wait for PAK exit)"
	fi
}

nextui_restored() {
	if [ -n "${ZLYME_PHASE14_TEST_NEXTUI:-}" ]; then
		[ "${ZLYME_PHASE14_TEST_NEXTUI}" = yes ]
		return $?
	fi
	pidof nextui.elf >/dev/null 2>&1
}

foreign_drm_clients() {
	# Prints foreign (non-nextui) DRM client PIDs. Empty means clean.
	if [ ! -r "$drm_clients_path" ]; then
		# Host tests without DRM: treat as clean unless a fixture says otherwise.
		if [ -n "${ZLYME_PHASE14_DRM_CLIENTS:-}" ]; then
			:
		else
			return 0
		fi
	fi
	[ -r "$drm_clients_path" ] || return 0
	awk 'NR>1 && $2 ~ /^[0-9]+$/ {print $2}' "$drm_clients_path" | while read -r p; do
		[ -n "$p" ] || continue
		cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || true)
		case "$cmd" in
			*nextui.elf* | '') ;;
			*)
				printf '%s\n' "$p"
				;;
		esac
	done
}

# Machine-proven cleanup gates for complete. User labels are separate.
require_completion_evidence() {
	cdir=$1
	ar=$cdir/active-run
	run_log=$(active_run_get run_log "$ar")
	[ -n "$run_log" ] && [ -f "$run_log" ] || die "complete refused: missing run_log"
	missing=

	require_claimer_ended complete "$cdir"

	if ! grep -q '^OBSERVE time=' "$run_log"; then
		missing="$missing observe"
	fi
	if ! grep -q '^NEXTUI_RESTORED process=yes$' "$run_log"; then
		# Live check may still pass if observe ran before NextUI returned.
		if nextui_restored; then
			echo "NEXTUI_RESTORED process=yes (live-check)" >> "$run_log"
		else
			missing="$missing nextui"
		fi
	fi
	if [ -r "$owned_mounts_path" ] && [ -s "$owned_mounts_path" ]; then
		missing="$missing mounts"
	elif grep -q '^OWNED_MOUNTS_REMAIN begin$' "$run_log"; then
		missing="$missing mounts"
	elif ! grep -q '^OWNED_MOUNTS_REMAIN none$' "$run_log"; then
		echo "OWNED_MOUNTS_REMAIN none (live-check)" >> "$run_log"
	fi
	if [ -e "$pak_cleanup_failed_path" ]; then
		missing="$missing pak_cleanup_125"
	fi
	foreign=$(foreign_drm_clients | tr '\n' ' ')
	if [ -n "$foreign" ]; then
		missing="$missing drm"
		echo "DRM_FOREIGN live=$foreign" >> "$run_log"
	fi
	if [ -f "$cdir/blocked" ]; then
		missing="$missing blocked"
	fi
	if [ -n "$missing" ]; then
		die "complete refused: missing evidence:$missing (active-run preserved; cursor not advanced)"
	fi
}

cmd_start() {
	mkdir -p "$root_state/campaigns"
	refuse_unresolved start

	gpu=$(gpu_name)
	sq=$(squashfs_id)
	bid=$(boot_id)
	lib=$(library_id)
	# Include pid so same-second starts cannot collide.
	base=$(date -u +%Y%m%dT%H%M%SZ)-$$-$gpu-$(printf '%s' "$bid" | cut -c1-8)
	cid=$base
	n=0
	while [ -e "$root_state/campaigns/$cid" ]; do
		n=$((n + 1))
		cid=${base}-$n
		[ "$n" -lt 1000 ] || die "could not allocate unique campaign id"
	done
	cdir=$root_state/campaigns/$cid
	mkdir -p "$cdir/runs" || die "campaign directory exists or not creatable: $cdir"
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
		printf 'format=4\n'
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
	refuse_unresolved reset
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
			if claimer_still_active "$cdir/active-run" 2>/dev/null; then
				echo "claimer=live"
			else
				echo "claimer=ended"
			fi
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
			printf '%s\n' "$n" | atomic_write "$cursor"
			idx=$n
			continue
		fi
		[ -f "$script" ] || die "queue script missing: $script"
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
	meta_lib=$(awk -F= '/^libraries=/{print substr($0, index($0, "=") + 1); exit}' "$cdir/meta.txt")
	cur_gpu=$(gpu_name)
	cur_boot=$(boot_id)
	cur_sq=$(squashfs_id)
	cur_lib=$(library_id)
	[ "$meta_gpu" = "$cur_gpu" ] || die "campaign gpu $meta_gpu != current $cur_gpu; start a new campaign"
	[ "$meta_boot" = "$cur_boot" ] || die "campaign boot_id changed; start a new campaign"
	[ "$meta_sq" = "$cur_sq" ] || die "campaign squashfs changed; start a new campaign"
	[ "$meta_lib" = "$cur_lib" ] || die "campaign libraries changed; start a new campaign"
	now=$(date +%s)
	suite_start=$(tr -d '\r\n' < "$cdir/suite-started")
	if [ $((now - suite_start)) -ge "$suite_budget" ]; then
		die "suite budget ${suite_budget}s exhausted; reset and start"
	fi
}

cmd_run() {
	cdir=$(campaign_dir)
	[ -f "$cdir/meta.txt" ] || die "campaign meta missing"
	[ -f "$cdir/blocked" ] && die "campaign blocked: $(cat "$cdir/blocked")"
	verify_campaign_identity "$cdir"

	if [ -f "$cdir/active-run" ]; then
		die "active-run already set; observe/complete/fail/retry before another launch"
	fi

	acquire_lock "$cdir"

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
	my_st=$(proc_starttime "$$") || {
		release_lock "$cdir"
		die "cannot read claimer starttime"
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
		printf 'claimer_starttime=%s\n' "$my_st"
		printf 'gpu=%s\n' "$meta_gpu"
		printf 'campaign=%s\n' "$(active_campaign)"
	} | atomic_write "$cdir/active-run"

	{
		echo "PHASE14_VALIDATE format=4"
		echo "START time=$(stamp) campaign=$(active_campaign) id=$id gpu=$meta_gpu"
		echo "SCRIPT $script"
		echo "PORTS_LAUNCH $ports"
		echo "CLAIMER pid=$$ starttime=$my_st"
		echo "NOTE no automated timeout; use MENU+START or natural exit"
		echo "NOTE complete requires ended claimer + observe cleanup evidence"
		echo "NOTE post-session evidence: phase14-portmaster-validate observe"
	} | atomic_write "$run_log"

	if [ -r "$drm_clients_path" ]; then
		others=$(awk 'NR>1 && $2 ~ /^[0-9]+$/ {print $2}' "$drm_clients_path" | tr '\n' ' ')
		for p in $others; do
			[ "$p" = "$$" ] && continue
			cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || true)
			case "$cmd" in
				*nextui.elf* | '') ;;
				*)
					echo "DRM_PRECHECK foreign_pid=$p cmd=$cmd" >> "$run_log"
					printf 'unresolved DRM client pid %s before launch\n' "$p" | atomic_write "$cdir/blocked"
					release_lock "$cdir"
					die "foreign DRM client $p still active; campaign blocked"
					;;
			esac
		done
	fi

	echo "phase14-validate exec PORTS.pak for $id (lock held; complete after observe)" >&2
	exec "$ports" "$script"
}

append_observe() {
	run_log=$1
	{
		echo "OBSERVE time=$(stamp)"
		if nextui_restored; then
			echo "NEXTUI_RESTORED process=yes"
		else
			echo "NEXTUI_RESTORED process=no"
		fi
		if [ -r "$drm_clients_path" ]; then
			awk '{ print "DRM_CLIENT " $0 }' "$drm_clients_path"
		else
			echo "DRM_CLIENTS unavailable"
		fi
		if [ -r "$owned_mounts_path" ] && [ -s "$owned_mounts_path" ]; then
			echo "OWNED_MOUNTS_REMAIN begin"
			cat "$owned_mounts_path"
			echo "OWNED_MOUNTS_REMAIN end"
		else
			echo "OWNED_MOUNTS_REMAIN none"
		fi
		if [ -e "$pak_cleanup_failed_path" ]; then
			echo "PAK_CLEANUP_FAILED yes"
			cat "$pak_cleanup_failed_path" 2>/dev/null || true
		else
			echo "PAK_CLEANUP_FAILED no"
		fi
		echo "NOTE visible frontend and audio/input require physical observation"
	} >> "$run_log"
}

cmd_observe() {
	cdir=$(campaign_dir)
	[ -f "$cdir/active-run" ] || die "no active-run to observe"
	require_claimer_ended observe "$cdir"
	run_log=$(active_run_get run_log "$cdir/active-run")
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
	next_idx=$(active_run_get queue_next_index "$cdir/active-run")
	case "$next_idx" in
		''|*[!0-9]*) die "active-run missing queue_next_index" ;;
	esac
	printf '%s\n' "$next_idx" | atomic_write "$cdir/cursor"
}

cmd_complete() {
	cdir=$(campaign_dir)
	[ -f "$cdir/active-run" ] || die "no active-run to complete"
	run_log=$(active_run_get run_log "$cdir/active-run")
	result=${1:-PASS_PROCESS}
	require_completion_evidence "$cdir"
	{
		echo "COMPLETE time=$(stamp) result=$result"
		echo "NOTE result=$result is a user label; cleanup evidence was machine-checked"
		echo "NOTE result=$result is not a render/input/MENU+START PASS by itself"
	} >> "$run_log"
	advance_past_active "$cdir"
	mv -f "$cdir/active-run" "$cdir/runs/completed-$(date -u +%Y%m%dT%H%M%SZ).active-run"
	release_lock "$cdir"
	echo "phase14-validate complete result=$result cursor=$(cat "$cdir/cursor")"
}

cmd_fail() {
	cdir=$(campaign_dir)
	[ -f "$cdir/active-run" ] || die "no active-run to fail"
	require_claimer_ended fail "$cdir"
	run_log=$(active_run_get run_log "$cdir/active-run")
	reason=${1:-unresolved}
	{
		echo "FAIL time=$(stamp) reason=$reason"
		echo "NOTE cursor not advanced; use retry after fixing"
	} >> "$run_log"
	printf '%s\n' "$reason" | atomic_write "$cdir/blocked"
	# Keep active-run; release lock only after claimer ended.
	release_lock "$cdir"
	echo "phase14-validate fail: $reason (active-run retained for retry)"
}

cmd_retry() {
	cdir=$(campaign_dir)
	if [ -f "$cdir/active-run" ]; then
		require_claimer_ended retry "$cdir"
		run_log=$(active_run_get run_log "$cdir/active-run")
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
