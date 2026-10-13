# Shared by test_usb_transfer.sh and usb_transfer_confined.sh.
# The caller defines fail. MENU+START sends TERM, waits 1.5s, then
# KILL to the PAK process group. The reaper is outside that group.
# The gadget directory appears before FunctionFS is mounted, so the
# signal waits until that mount exists. A reaper that has already
# finished, and left nothing behind, is success. It does not have to
# still be running.
# shellcheck shell=sh

check_presenter_pages() {
	_pages=$1
	[ -s "$_pages" ] || fail "presenter recorded no pages"
	_bad=$(
		awk '
			function flush(   i) {
				if (n == 0) return
				if (n > 6) {
					printf "page has %d lines\n", n
					bad = 1
				}
				for (i = 1; i <= n; i++) {
					if (line[i] == "") {
						printf "page has a blank line\n"
						bad = 1
					}
					if (length(line[i]) > 38 && line[i] != "Connect your computer to the lower USB-C port.") {
						printf "line has %d characters\n", length(line[i])
						bad = 1
					}
				}
				n = 0
			}
			/^---$/ { flush(); next }
			{ n++; line[n] = $0 }
			END { flush(); if (bad) exit 1 }
		' "$_pages"
	) || fail "presenter layout: $_bad"
}

_leftover_state() {
	_ls_gadget=$1
	_ls_mounts=$2
	_ls_ffs=$3
	_ls_run=$4
	_ls_bits=
	if [ -d "$_ls_gadget" ]; then
		_ls_bits="${_ls_bits}gadget "
	fi
	if grep -F -q " ${_ls_ffs} " "$_ls_mounts"; then
		_ls_bits="${_ls_bits}functionfs "
	fi
	if [ -s "$_ls_run/responder.pid" ]; then
		_ls_opid=$(cat "$_ls_run/responder.pid")
		if kill -0 "$_ls_opid" 2>/dev/null; then
			_ls_bits="${_ls_bits}responder "
		fi
	fi
	if grep -q configfs "$_ls_mounts"; then
		_ls_bits="${_ls_bits}configfs "
	fi
	if [ -s "$_ls_run/reaper.log" ] && grep -q 'cleanup incomplete' "$_ls_run/reaper.log"; then
		_ls_bits="${_ls_bits}cleanup-failed "
	fi
	printf '%s' "$_ls_bits"
}

prove_group_reaper() {
	_label=$1
	_run=$2
	_gadget=$3
	_mounts=$4
	_ffs=$5
	_pgrp=$6
	_mark=$7
	_i=0
	while [ "$_i" -lt 80 ]; do
		if [ -s "$_run/reaper.pgid" ] && [ -d "$_gadget" ] \
			&& [ -s "$_run/responder.pid" ] \
			&& grep -F -q " ${_ffs} " "$_mounts"; then
			break
		fi
		_i=$((_i + 1))
		sleep 0.05
	done
	[ -d "$_gadget" ] || fail "$_label: gadget was not created"
	grep -F -q " ${_ffs} " "$_mounts" \
		|| fail "$_label: FunctionFS was not mounted before the group signal"
	[ -s "$_run/responder.pid" ] \
		|| fail "$_label: responder was not running before the group signal"
	_rpg=$(cat "$_run/reaper.pgid")
	[ "$_rpg" != "$_pgrp" ] || fail "$_label: reaper stayed in the pak group"
	_rpid=$(cat "$_run/reaper.pid")
	rm -f "$_mark"

	kill -s TERM -- "-$_pgrp"
	sleep 1.5
	kill -s KILL -- "-$_pgrp" 2>/dev/null || true

	_left=$(_leftover_state "$_gadget" "$_mounts" "$_ffs" "$_run")
	if ! kill -0 "$_rpid" 2>/dev/null; then
		if [ -n "$_left" ]; then
			fail "$_label: reaper terminated during cleanup; leftover ${_left}"
		fi
		return 0
	fi

	_i=0
	while [ "$_i" -lt 40 ]; do
		kill -0 "$_rpid" 2>/dev/null || break
		_i=$((_i + 1))
		sleep 0.1
	done
	_left=$(_leftover_state "$_gadget" "$_mounts" "$_ffs" "$_run")
	if kill -0 "$_rpid" 2>/dev/null; then
		fail "$_label: reaper still running; leftover ${_left:-none}"
	fi
	if [ -n "$_left" ]; then
		fail "$_label: cleanup failure; leftover ${_left}"
	fi
}
