#!/bin/sh
# Settings → Game housekeeping. Walk /run/zlyme/libraries.
# First line of stdout is COUNT=n. Rest is a short summary.

set -u

DRY=0
ACTION=${1:-}
[ "${2:-}" = "--dry-run" ] && DRY=1
[ "${1:-}" = "--dry-run" ] && DRY=1 && ACTION=${2:-}

LIBRARIES=/run/zlyme/libraries
SAVE_FORMAT=${SAVE_FORMAT:-0}
STATE_FORMAT=${STATE_FORMAT:-0}

list_roots() {
	if [ -f "$LIBRARIES" ]; then
		cat "$LIBRARIES"
	else
		echo /storage
	fi
}

count=0
summary=

bump() {
	n=$1
	msg=$2
	count=$((count + n))
	[ -n "$msg" ] && summary="$summary$msg
"
}

is_junk_name() {
	b=$1
	case "$b" in
		.DS_Store|Thumbs.db|desktop.ini) return 0 ;;
		._*) return 0 ;;
		__MACOSX) return 0 ;;
		'$RECYCLE.BIN'|'$Recycle.Bin') return 0 ;;
		.Trash|.Trash-*|'.Trash-'*) return 0 ;;
	esac
	return 1
}

do_junk() {
	n=0
	list_roots | while IFS= read -r root; do
		[ -d "$root" ] || continue
		find "$root" \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name 'desktop.ini' \
			-o -name '._*' -o -name '__MACOSX' -o -name '.Trash' -o -name '.Trash-*' \
			-o -name '$RECYCLE.BIN' -o -name '$Recycle.Bin' \) 2>/dev/null
	done > /tmp/zlyme-junk.list
	n=$(wc -l < /tmp/zlyme-junk.list | tr -d ' ')
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			rm -rf "$f"
		done < /tmp/zlyme-junk.list
	fi
	printf '%s\n' "$n"
}

rom_stems() {
	root=$1
	roms=
	if [ -d "$root/Roms" ]; then
		roms=$root/Roms
	elif [ -d "$root/roms" ]; then
		roms=$root/roms
	else
		return 0
	fi
	find "$roms" -type f ! -path '*/.media/*' ! -name '.*' 2>/dev/null |
	while IFS= read -r f; do
		b=$(basename "$f")
		stem=$b
		stem=${stem%.*}
		printf '%s\n' "$stem"
		# MinUI Game.gba.sav → also Game
		stem2=${stem%.*}
		[ "$stem2" != "$stem" ] && printf '%s\n' "$stem2"
	done | sort -u
}

is_save_name() {
	b=$1
	case "$b" in
		*.sav|*.srm|*.state|*.state[0-9]|*.state.[0-9]|*.st[0-9]|*.auto) return 0 ;;
		*.rtc|*.mcr|*.eep|*.fla|*.nv) return 0 ;;
	esac
	return 1
}

append_orphan() {
	stems=$1
	f=$2
	b=$(basename "$f")
	stem=$b
	stem=${stem%.*}
	stem2=${stem%.*}
	hit=0
	printf '%s\n' "$stems" | grep -Fxq "$stem" && hit=1
	[ "$hit" = 0 ] && printf '%s\n' "$stems" | grep -Fxq "$stem2" && hit=1
	[ "$hit" = 0 ] && printf '%s\n' "$f"
}

do_orphan_saves() {
	n=0
	: > /tmp/zlyme-orph.list
	list_roots | while IFS= read -r root; do
		[ -d "$root/Saves" ] || continue
		stems=$(rom_stems "$root")
		find "$root/Saves" -type f 2>/dev/null |
		while IFS= read -r f; do
			b=$(basename "$f")
			is_save_name "$b" || continue
			append_orphan "$stems" "$f"
		done
		# DraStic slots (paks bind Saves/NDS/{backup,savestates})
		for d in "$root/Saves/NDS/backup" "$root/Saves/NDS/savestates" "$root/Saves/NDS"; do
			[ -d "$d" ] || continue
			find "$d" -maxdepth 1 -type f \( -name '*.dsv' -o -name '*.dst' -o -name '*.dsv.*' \) 2>/dev/null |
			while IFS= read -r f; do
				append_orphan "$stems" "$f"
			done
		done
		# OpenBOR .sav next to the pak (launch.sh cds to the ROM dir)
		for roms in "$root/Roms" "$root/roms"; do
			[ -d "$roms" ] || continue
			find "$roms" -type d \( -name '*OPENBOR*' -o -name '*OpenBOR*' \) 2>/dev/null |
			while IFS= read -r od; do
				find "$od" -maxdepth 2 -type f -name '*.sav' 2>/dev/null |
				while IFS= read -r f; do
					append_orphan "$stems" "$f"
				done
			done
		done
		# PortMaster savedata: sibling of a missing .sh
		for ports in "$root/Roms/Ports (PORTS)" "$root/Roms/ports" "$root/roms/ports"; do
			[ -d "$ports" ] || continue
			find "$ports" -type d \( -name savedata -o -name saves \) 2>/dev/null |
			while IFS= read -r sd; do
				parent=$(dirname "$sd")
				sh=
				for c in "$parent"/*.sh "$parent"/*.SH; do
					[ -f "$c" ] && sh=$c && break
				done
				[ -n "$sh" ] && continue
				printf '%s\n' "$sd"
			done
		done
	done >> /tmp/zlyme-orph.list
	n=$(wc -l < /tmp/zlyme-orph.list | tr -d ' ')
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			rm -rf "$f"
		done < /tmp/zlyme-orph.list
	fi
	printf '%s\n' "$n"
}

do_orphan_media() {
	: > /tmp/zlyme-media.list
	list_roots | while IFS= read -r root; do
		roms=
		[ -d "$root/Roms" ] && roms=$root/Roms
		[ -d "$root/roms" ] && roms=$root/roms
		[ -n "$roms" ] || continue
		find "$roms" -type d -name '.media' 2>/dev/null |
		while IFS= read -r md; do
			parent=$(dirname "$md")
			find "$md" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) 2>/dev/null |
			while IFS= read -r img; do
				stem=$(basename "$img")
				stem=${stem%.*}
				found=0
				for f in "$parent/$stem".*; do
					[ -f "$f" ] || continue
					case "$f" in
						*/.media/*) continue ;;
					esac
					found=1
					break
				done
				[ "$found" = 0 ] && printf '%s\n' "$img"
			done
		done
	done >> /tmp/zlyme-media.list
	n=$(wc -l < /tmp/zlyme-media.list | tr -d ' ')
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			rm -f "$f"
		done < /tmp/zlyme-media.list
	fi
	printf '%s\n' "$n"
}

do_recents() {
	f=/storage/.config/nextui/shared/.minui/recent.txt
	if [ -f "$f" ]; then
		n=$(wc -l < "$f" | tr -d ' ')
		[ "$DRY" = 0 ] && : > "$f"
		printf '%s\n' "$n"
	else
		printf '0\n'
	fi
}

do_ra_cores() {
	d=/storage/.config/retroarch/config
	n=0
	if [ -d "$d" ]; then
		n=$(find "$d" -type f | wc -l | tr -d ' ')
		[ "$DRY" = 0 ] && rm -rf "$d"
	fi
	printf '%s\n' "$n"
}

do_standalones() {
	# names printed to stderr-style list file
	: > /tmp/zlyme-sa.list
	for p in \
		/storage/.config/ppsspp \
		/storage/.config/flycast \
		/storage/.config/dolphin-emu \
		/storage/.config/drastic \
		/storage/.config/aethersx2 \
		/storage/.config/nextui/shared/configs/gzdoom \
		/storage/.config/nextui/shared/Pico-8-native \
		/storage/.config/nextui/my355/wine
	do
		[ -e "$p" ] || continue
		printf '%s\n' "$p" >> /tmp/zlyme-sa.list
	done
	n=$(wc -l < /tmp/zlyme-sa.list | tr -d ' ')
	if [ "$DRY" = 0 ]; then
		while IFS= read -r p; do
			rm -rf "$p"
		done < /tmp/zlyme-sa.list
	fi
	printf '%s\n' "$n"
	if [ "$n" -gt 0 ]; then
		tr '\n' ',' < /tmp/zlyme-sa.list | sed 's/,$/\n/'
	fi
}

do_ra_rom_cfg() {
	d=/storage/.config/retroarch/config
	: > /tmp/zlyme-racfg.list
	stems=$(list_roots | while IFS= read -r root; do rom_stems "$root"; done | sort -u)
	if [ -d "$d" ]; then
		find "$d" -type f -name '*.cfg' ! -name '*libretro.cfg' 2>/dev/null |
		while IFS= read -r f; do
			b=$(basename "$f" .cfg)
			printf '%s\n' "$stems" | grep -Fxq "$b" && continue
			printf '%s\n' "$f"
		done >> /tmp/zlyme-racfg.list
	fi
	n=$(wc -l < /tmp/zlyme-racfg.list | tr -d ' ')
	if [ "$DRY" = 0 ] && [ "$n" -gt 0 ]; then
		while IFS= read -r f; do
			rm -f "$f"
		done < /tmp/zlyme-racfg.list
	fi
	printf '%s\n' "$n"
}

case "$ACTION" in
	junk) n=$(do_junk); echo "COUNT=$n"; echo "junk files" ;;
	orphan-saves) n=$(do_orphan_saves); echo "COUNT=$n"; echo "orphan saves" ;;
	orphan-media) n=$(do_orphan_media); echo "COUNT=$n"; echo "orphan boxart" ;;
	recents) n=$(do_recents); echo "COUNT=$n"; echo "recents" ;;
	ra-cores) n=$(do_ra_cores); echo "COUNT=$n"; echo "RetroArch core options" ;;
	standalones) n=$(do_standalones); echo "COUNT=$n" ;;
	ra-rom-cfg) n=$(do_ra_rom_cfg); echo "COUNT=$n"; echo "per-ROM RetroArch configs" ;;
	*)
		echo "usage: $0 {junk|orphan-saves|orphan-media|recents|ra-cores|standalones|ra-rom-cfg} [--dry-run]" >&2
		exit 1
		;;
esac
