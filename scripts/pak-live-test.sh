#!/bin/sh
# Launch every Tools pak and every Emus pak that has a ROM, then return
# with MENU+Start. Run on the device as root.
set -u

LOG=/storage/.config/zlyme/pak-live-test.log
RES=/storage/.config/zlyme/pak-live-test.txt
NXT=/storage/.config/nextui/my355/logs/next.txt
: >"$LOG"
: >"$RES"
mkdir -p /storage/.config/zlyme
touch /tmp/zlyme-keep-emu

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

inject_menu_start() {
	python3 - <<'PY'
import os, struct, time
EV_SYN, EV_KEY = 0, 1
BTN_START, BTN_MODE = 0x13b, 0x13c
def pkt(t, c, v):
    return struct.pack("llHHi", 0, 0, t, c, v)
fd = os.open("/dev/input/event4", os.O_WRONLY)
os.write(fd, pkt(EV_KEY, BTN_MODE, 1) + pkt(EV_KEY, BTN_START, 1) + pkt(EV_SYN, 0, 0))
time.sleep(0.35)
os.write(fd, pkt(EV_KEY, BTN_MODE, 0) + pkt(EV_KEY, BTN_START, 0) + pkt(EV_SYN, 0, 0))
os.close(fd)
PY
}

nuke_paks() {
	killall -9 retroarch ra-run PPSSPPSDL flycast drastic start_drastic scummvm pico8 \
		moonlight-pak moonlight moonlight-qt portmaster vtree settings.elf scrapegoat \
		minui-list minui-presenter show.elf hypseus python3 gm gmloader \
		ags bluetoothctl zlyme-pak-hotkey aethersx2 dolphin-emu-nogui \
		start_dolphin amiberry OpenBOR gzdoom easyrpg-player tic80 \
		box64 wineserver 2>/dev/null || true
	# Moonlight has leaked card0 across paks; BusyBox fuser has no -v.
	fuser -k /dev/dri/card0 2>/dev/null || true
}

wait_nextui() {
	n=$1
	i=0
	while [ "$i" -lt "$n" ]; do
		pidof nextui.elf >/dev/null 2>&1 && return 0
		sleep 0.2
		i=$((i + 1))
	done
	return 1
}

pak_running() {
	pidof retroarch PPSSPPSDL flycast drastic start_drastic scummvm pico8 \
		moonlight-pak moonlight portmaster vtree settings.elf scrapegoat \
		minui-list minui-presenter show.elf hypseus gm gmloader \
		aethersx2 dolphin-emu-nogui start_dolphin amiberry OpenBOR \
		gzdoom >/dev/null 2>&1
}

ensure_session() {
	n=$(pidof nextui-session 2>/dev/null | wc -w)
	if [ "$n" -gt 1 ]; then
		log "multiple sessions ($n); keeping one"
		# busybox pidof prints space-separated
		set -- $(pidof nextui-session)
		shift
		kill -9 "$@" 2>/dev/null || true
	fi
	if pidof nextui-session >/dev/null 2>&1; then
		return 0
	fi
	log "session died; restarting"
	/usr/sbin/nextui-session >>/storage/.config/zlyme/nextui-session.log 2>&1 &
	wait_nextui 80 || log "session restart failed"
}

run() {
	tag=$1
	cmd=$2
	hold_ticks=$3
	log ""
	log "=== $tag ==="
	# Drop leaked DRM (Moonlight has left card0 open) before NextUI.
	killall -9 moonlight-pak moonlight moonlight-qt 2>/dev/null || true
	ensure_session
	if ! wait_nextui 40; then
		log "nextui missing; closing leftover pak"
		inject_menu_start
		nuke_paks
		wait_nextui 50 || true
	fi
	if ! wait_nextui 50; then
		log "FAIL $tag no-nextui-before"
		echo "FAIL $tag no-nextui-before" >>"$RES"
		return 0
	fi
	printf '%s\n' "$cmd" >/tmp/next
	# SIGTERM so NextUI drops DRM. -9 leaves the plane and SDL/RA/Dolphin
	# then die with "kmsdrm not available" / "Failed to initialize video".
	kill $(pidof nextui.elf) 2>/dev/null || true
	g=0
	while pidof nextui.elf >/dev/null 2>&1 && [ "$g" -lt 25 ]; do
		sleep 0.2
		g=$((g + 1))
	done
	if pidof nextui.elf >/dev/null 2>&1; then
		kill -9 $(pidof nextui.elf) 2>/dev/null || true
		sleep 0.8
	fi
	sleep 0.8
	# Give the pak time to take DRM before MENU+Start.
	i=0
	mode=hold
	while [ "$i" -lt "$hold_ticks" ]; do
		if pidof nextui.elf >/dev/null 2>&1; then
			mode=self
			break
		fi
		if [ "$i" -eq 8 ]; then
			log "gov tag=$tag cpu=$(tr -d '\n' </sys/devices/system/cpu/online) min=$(tr -d '\n' </sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq) gov=$(tr -d '\n' </sys/devices/system/cpu/cpu0/cpufreq/scaling_governor) dmc=$(tr -d '\n' </sys/class/devfreq/dmc/min_freq 2>/dev/null)"
			ls -l "/storage/.logs/${tag}.log" 2>/dev/null | tee -a "$LOG" || log "no ${tag}.log yet"
		fi
		sleep 0.2
		i=$((i + 1))
	done
	log "mode=$mode ticks=$i cmd=$cmd"
	if [ "$mode" = self ]; then
		sleep 0.3
		grep -E "RUN |pak exit" "$NXT" 2>/dev/null | tail -5 | tee -a "$LOG"
		echo "PASS_EXIT $tag" >>"$RES"
		log "PASS_EXIT $tag"
		return 0
	fi
	inject_menu_start
	if wait_nextui 50; then
		echo "PASS $tag" >>"$RES"
		log "PASS $tag"
		return 0
	fi
	log "MENU+Start miss; killing pak"
	nuke_paks
	if wait_nextui 50; then
		echo "PASS_KILL $tag" >>"$RES"
		log "PASS_KILL $tag"
		return 0
	fi
	echo "FAIL $tag hung" >>"$RES"
	log "FAIL $tag hung"
	ensure_session
}

log "start $(date -u) up=$(cut -d' ' -f1 /proc/uptime)"
killall nextui-session 2>/dev/null || true
# SIGTERM so NextUI drops DRM. -9 leaves kmsdrm held for the first pak.
kill $(pidof nextui.elf) 2>/dev/null || true
g=0
while pidof nextui.elf >/dev/null 2>&1 && [ "$g" -lt 25 ]; do
	sleep 0.2
	g=$((g + 1))
done
if pidof nextui.elf >/dev/null 2>&1; then
	kill -9 $(pidof nextui.elf) 2>/dev/null || true
	sleep 0.4
fi
nuke_paks
sleep 0.4
/usr/sbin/nextui-session >>/storage/.config/zlyme/nextui-session.log 2>&1 &
if ! wait_nextui 80; then
	log "FAIL could not start nextui-session"
	exit 1
fi
log "session=$(pidof nextui-session) nextui=$(pidof nextui.elf)"
log "sd2=$(zlyme-storage status 2>/dev/null | tr '\n' ' ')"
log "mergerfs=$(getfattr -n user.mergerfs.srcmounts --only-values /storage/Roms/.mergerfs 2>/dev/null)"

# Tools that failed last pass.
run ScrapeGoat "'/storage/Tools/my355/ScrapeGoat.pak/launch.sh'" 20
run Moonlight "'/storage/Tools/my355/Moonlight.pak/launch.sh'" 20
run ArtworkScraper "'/storage/Tools/my355/Artwork Scraper.pak/launch.sh'" 20
run Overlays "'/storage/Tools/my355/Overlays.pak/launch.sh'" 25
run Settings "'/storage/Tools/my355/Settings.pak/launch.sh'" 20
run Files "'/storage/Tools/my355/Files.pak/launch.sh'" 20
run Autocal "'/storage/Tools/my355/Autocal.pak/launch.sh'" 20
run PortMaster "'/storage/Tools/my355/PortMaster.pak/launch.sh'" 25

# Prefer OS-card test files, then the merged list. Skip PortMaster
# vendor trees and boxart. Pico-8 carts are .p8/.png.
first_rom() {
	pretty=$1
	tag=$2
	depth=3
	case "$tag" in
		MKXPZ|EASYRPG|SCUMMVM|PORTS) depth=5 ;;
	esac
	for root in /storage/.roms_base /storage/Roms; do
		[ -d "$root/$pretty" ] || continue
		f=$(
			find "$root/$pretty" -maxdepth "$depth" -type f ! -name '.*' \
				! -iname 'readme*' ! -iname '*.txt' ! -iname '*.md' \
				! -iname '*.jpg' ! -iname '*.jpeg' ! -iname '*.xml' \
				! -iname '*.srm' ! -iname '*.sav' ! -iname '*.state' \
				! -iname '*.rtc' ! -iname '*.mcr' ! -iname '*.eep' \
				! -iname '*.fla' ! -iname '*.nv' ! -iname '*.mcr' \
				! -path '*/.media/*' ! -path '*/PortMaster/*' \
				2>/dev/null |
			case "$tag" in
				PICO|P8) cat ;;
				PORTS) grep -iE '\.sh$' ;;
				*) grep -viE '\.(png|gif|bmp|ogg|wav|mp3)$' ;;
			esac | head -n 1
		)
		if [ -n "$f" ]; then
			printf '%s\n' "$f"
			return 0
		fi
	done
	return 1
}

run_rom() {
	tag=$1
	pretty=$2
	hold=${3:-25}
	pak="/storage/Emus/my355/${tag}.pak/launch.sh"
	if [ ! -f "$pak" ]; then
		echo "SKIP $tag no-pak" >>"$RES"
		log "SKIP $tag no-pak"
		return 0
	fi
	rom=$(first_rom "$pretty" "$tag")
	if [ -z "$rom" ]; then
		echo "SKIP $tag no-rom" >>"$RES"
		log "SKIP $tag no-rom"
		return 0
	fi
	run "$tag" "'$pak' '$rom'" "$hold"
}

run_rom GB "Game Boy (GB)" 25
run_rom GBC "Game Boy Color (GBC)" 25
run_rom FC "Nintendo Entertainment System (FC)" 25
run_rom GBA "Game Boy Advance (GBA)" 25
run_rom SFC "Super Nintendo Entertainment System (SFC)" 25
run_rom MD "Sega Genesis (MD)" 25
run_rom MS "Sega Master System (MS)" 25
run_rom GG "Sega Game Gear (GG)" 25
run_rom 32X "Sega 32X (32X)" 25
run_rom DC "Sega Dreamcast (DC)" 40
run_rom N64 "Nintendo 64 (N64)" 40
run_rom NDS "Nintendo DS (NDS)" 40
run_rom PCE "PC Engine (PCE)" 25
run_rom NGP "Neo Geo Pocket (NGP)" 25
run_rom WS "WonderSwan (WS)" 25
run_rom VB "Virtual Boy (VB)" 25
run_rom LYNX "Atari Lynx (LYNX)" 25
run_rom A26 "Atari 2600 (A26)" 25
run_rom A5200 "Atari 5200 (A5200)" 25
run_rom A78 "Atari 7800 (A78)" 25
run_rom A800 "Atari 8-bit (A800)" 25
run_rom ST "Atari ST (ST)" 30
run_rom COLECO "ColecoVision (COLECO)" 25
run_rom INTV "Intellivision (INTV)" 25
run_rom MSX "MSX (MSX)" 25
run_rom O2 "Odyssey 2 (O2)" 25
run_rom SG1000 "Sega SG-1000 (SG1000)" 25
run_rom SGX "SuperGrafx (SGX)" 25
run_rom VEC "Vectrex (VEC)" 25
run_rom PKM "Pokemon Mini (PKM)" 25
run_rom FBNEO "FBNeo (FBNEO)" 35
run_rom MAME "MAME (MAME)" 35
run_rom DOS "DOS (DOS)" 30
run_rom 3DO "3DO (3DO)" 40
run_rom NEOCD "Neo Geo CD (NEOCD)" 40
run_rom SATURN "Sega Saturn (SATURN)" 40
run_rom AMIGA "Commodore Amiga (AMIGA)" 35
run_rom TIC "TIC-80 (TIC)" 25
run_rom P8 "Pico-8 fake-08 (P8)" 25
run_rom EASYRPG "RPG Maker 2000-2003 (EASYRPG)" 40
run_rom MKXPZ "RPG Maker XP-VX-Ace (MKXPZ)" 30
run_rom OPENBOR "OpenBOR (OPENBOR)" 30
run_rom DAPHNE "Daphne (DAPHNE)" 30
run_rom WINE "Windows (WINE)" 35
run_rom DOOM "Doom (DOOM)" 35
run_rom SCUMMVM "ScummVM (SCUMMVM)" 30
run_rom PICO "Pico-8 (PICO)" 25
run_rom PORTS "Ports (PORTS)" 30
run_rom PS "Sony PlayStation (PS)" 40
run_rom PSP "Sony PlayStation Portable (PSP)" 40
run_rom PS2 "Sony PlayStation 2 (PS2)" 50
run_rom GC "Nintendo GameCube (GC)" 50
run_rom WII "Nintendo Wii (WII)" 50

log ""
log "done $(date -u)"
log "---- results ----"
tee -a "$LOG" <"$RES"
rm -f /tmp/zlyme-keep-emu
ensure_session
wait_nextui 50 || true
log "nextui=$(pidof nextui.elf || echo none) session=$(pidof nextui-session || echo none)"
