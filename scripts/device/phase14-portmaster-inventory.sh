#!/bin/sh
# SPDX-License-Identifier: MIT
# Classify installed PortMaster top-level launchers. Read-only.
# Does not launch games, download runtimes, or alter saves.
set -eu

out_dir=${1:-/storage/.config/zlyme/phase14-validate}
mkdir -p "$out_dir"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
report=$out_dir/inventory-$stamp.txt
queue=$out_dir/queue.txt
: > "$report"
: > "$queue"

gpu=unknown
if [ -r /storage/.config/zlyme/gpu ]; then
	gpu=$(tr -d '\r\n' < /storage/.config/zlyme/gpu)
fi
printf 'PHASE14_INVENTORY stamp=%s gpu=%s\n' "$stamp" "$gpu" | tee -a "$report"

libraries=
if [ -r /run/zlyme/libraries ]; then
	libraries=$(cat /run/zlyme/libraries)
elif [ -d /mnt/sd2/Roms ]; then
	libraries=/mnt/sd2
elif [ -d /storage/Roms ]; then
	libraries=/storage
fi

classify_one() {
	script=$1
	base=$(basename "$script")
	id=$(printf '%s' "$base" | tr ' /' '__' | tr -cd 'A-Za-z0-9._-')
	dir=$(dirname "$script")
	ready=ELIGIBLE
	notes=

	case "$base" in
		.* | *.gptk | *.txt | *.json | *.png | *.jpg | *.jpeg | *.md)
			return 0
			;;
	esac
	[ -f "$script" ] || return 0
	[ -x "$script" ] || [ "${script%.sh}" != "$script" ] || return 0

	case "$base" in
		*[Ss]kautfold*)
			if [ ! -f "$dir/../ports/skautfoldinsanity/saves/game.droid" ] &&
			   [ ! -f /roms/ports/skautfoldinsanity/saves/game.droid ]; then
				ready=EXTERNAL_DATA_REQUIRED
				notes="missing game.droid under skautfoldinsanity/saves"
			fi
			;;
		*[Ss]teel*[Aa]ssault*)
			mono=
			for cand in \
				"/mnt/sd2/Roms/Ports (PORTS)/PortMaster/libs/mono-6.12.0.122-aarch64.squashfs" \
				/mnt/sd2/Tools/PortMaster/libs/mono-6.12.0.122-aarch64.squashfs \
				/storage/Tools/PortMaster/libs/mono-6.12.0.122-aarch64.squashfs
			do
				if [ -f "$cand" ]; then
					mono=$cand
					break
				fi
			done
			if [ -z "$mono" ]; then
				ready=MISSING_RUNTIME
				notes="mono-6.12.0.122-aarch64.squashfs not found under PortMaster/libs"
			else
				notes="mono squashfs present at $mono; prior log was mono: command not found"
			fi
			;;
		*[Ss]hards*)
			dir=$(dirname "$script")
			# shell port dir is usually sibling of the .sh via PortMaster layout
			gdir=
			for cand in "$dir/shardsofgod" "/mnt/sd2/Roms/Ports (PORTS)/shardsofgod"; do
				[ -d "$cand" ] && gdir=$cand && break
			done
			if [ -n "$gdir" ] && [ ! -f "$gdir/shardsofgod.gptk" ]; then
				notes="missing shardsofgod.gptk (Syncthing conflict name present?); launch ELIGIBLE but controls will fail"
			fi
			;;
		*[Mm]ina*)
			ready=ELIGIBLE
			notes="requires complete bounded log; Vulkan ICD presence is not success"
			;;
	esac

	printf 'PORT id=%s ready=%s script=%s notes=%s\n' \
		"$id" "$ready" "$script" "$notes" | tee -a "$report"
	printf '%s\t%s\t%s\n' "$ready" "$id" "$script" >> "$queue"
}

printf 'LIBRARIES %s\n' "$libraries" | tee -a "$report"
for lib in $libraries; do
	ports="$lib/Roms/Ports (PORTS)"
	[ -d "$ports" ] || ports=$lib/Roms/PORTS
	[ -d "$ports" ] || continue
	printf 'SCAN %s\n' "$ports" | tee -a "$report"
	for script in "$ports"/*.sh; do
		[ -e "$script" ] || continue
		[ -f "$script" ] || continue
		classify_one "$script"
	done
done

eligible=0
blocked=0
while IFS="$(printf '\t')" read -r ready id script; do
	[ -n "${ready:-}" ] || continue
	case "$ready" in
		ELIGIBLE) eligible=$((eligible + 1)) ;;
		*) blocked=$((blocked + 1)) ;;
	esac
done < "$queue"

printf 'SUMMARY eligible=%s blocked=%s report=%s queue=%s\n' \
	"$eligible" "$blocked" "$report" "$queue" | tee -a "$report"
