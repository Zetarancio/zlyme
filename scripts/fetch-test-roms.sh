#!/bin/sh
# Download one legal homebrew / freeware / author-granted test per
# NextUI TAG where one exists. Never No-Intro, Redump, or scene sets.
# Soft-fail per system (SKIP + why).
#
# Dest: ZLYME_ROMS, else /storage/Roms on device, else a mounted ZLYME/Roms on the host.
set -u

log() { printf '%s\n' "$*"; }

skip() {
	tag=$1
	why=$2
	log "SKIP $tag: $why"
}

die() {
	log "ERROR: $*"
	exit 1
}

find_dest() {
	if [ -n "${ZLYME_ROMS:-}" ]; then
		printf '%s\n' "$ZLYME_ROMS"
		return 0
	fi
	if [ -d /storage/Roms ]; then
		printf '%s\n' /storage/Roms
		return 0
	fi
	# Host: OS card labelled ZLYME only. Never SD2/USB games cards.
	for d in /run/media/*/ZLYME/Roms /media/*/ZLYME/Roms /mnt/ZLYME/Roms; do
		[ -d "$d" ] || continue
		printf '%s\n' "$d"
		return 0
	done
	if command -v findmnt >/dev/null 2>&1; then
		mp=$(findmnt -n -o TARGET LABEL=ZLYME 2>/dev/null | head -n1)
		if [ -n "$mp" ] && [ -d "$mp/Roms" ]; then
			printf '%s\n' "$mp/Roms"
			return 0
		fi
	fi
	return 1
}

DEST=$(find_dest) || die "no ROM dest (set ZLYME_ROMS= or mount ZLYME)"
mkdir -p "$DEST" || die "cannot mkdir $DEST"
log "dest=$DEST"

command -v curl >/dev/null 2>&1 || die "curl is missing"

TMP=$(mktemp -d) || die "mktemp"
trap 'rm -rf "$TMP"' EXIT

fetch() {
	url=$1
	out=$2
	secs=${3:-240}
	curl -fL --connect-timeout 20 --max-time "$secs" --retry 2 -o "$out" "$url"
}

unzip_into() {
	archive=$1
	outdir=$2
	mkdir -p "$outdir"
	if command -v unzip >/dev/null 2>&1; then
		unzip -o -q "$archive" -d "$outdir"
		return $?
	fi
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$archive" "$outdir" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
		return $?
	fi
	return 1
}

put_file() {
	pretty=$1
	src=$2
	name=$3
	dir="$DEST/$pretty"
	mkdir -p "$dir"
	cp -f "$src" "$dir/$name"
	log "OK $pretty <- $name"
}

put_zip() {
	pretty=$1
	src=$2
	dir="$DEST/$pretty"
	unzip_into "$src" "$dir" || return 1
	log "OK $pretty <- zip"
}

# Find the first extracted file matching a glob (case-insensitive).
find_member() {
	root=$1
	pat=$2
	find "$root" -type f -iname "$pat" 2>/dev/null | head -n 1
}

zip_dir() {
	srcdir=$1
	outzip=$2
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$srcdir" "$outzip" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
base = os.path.basename(src.rstrip("/"))
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, _, files in os.walk(src):
        for fn in files:
            path = os.path.join(dirpath, fn)
            rel = os.path.join(base, os.path.relpath(path, src))
            z.write(path, rel)
PY
		return $?
	fi
	return 1
}

try_file() {
	tag=$1
	pretty=$2
	name=$3
	url=$4
	secs=${5:-240}
	if fetch "$url" "$TMP/$name" "$secs"; then
		put_file "$pretty" "$TMP/$name" "$name"
		return 0
	fi
	skip "$tag" "download failed ($name)"
	return 1
}

try_zip_member() {
	tag=$1
	pretty=$2
	name=$3
	url=$4
	pat=$5
	secs=${6:-240}
	if ! fetch "$url" "$TMP/$tag.zip" "$secs"; then
		skip "$tag" "download failed ($url)"
		return 1
	fi
	mkdir -p "$TMP/$tag"
	if ! unzip_into "$TMP/$tag.zip" "$TMP/$tag"; then
		skip "$tag" "unzip failed"
		return 1
	fi
	src=$(find_member "$TMP/$tag" "$pat")
	if [ -z "$src" ]; then
		skip "$tag" "zip had no $pat"
		return 1
	fi
	put_file "$pretty" "$src" "$name"
}

# --- already-pinned legal tests ---

# Game Boy — blargg cpu_instrs (public test ROM)
try_file GB "Game Boy (GB)" "cpu_instrs.gb" \
	"https://github.com/retrio/gb-test-roms/raw/master/cpu_instrs/cpu_instrs.gb"

# NES — nestest (public test ROM, Kevin Horton / community dumps on GitHub)
try_file FC "Nintendo Entertainment System (FC)" "nestest.nes" \
	"https://github.com/christopherpow/nes-test-roms/raw/master/other/nestest.nes"

# Doom — Freedoom Phase 1 (BSD). https://freedoom.github.io/
if fetch "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip" \
	"$TMP/freedoom.zip" 300; then
	mkdir -p "$TMP/freedoom"
	if unzip_into "$TMP/freedoom.zip" "$TMP/freedoom"; then
		wad=$(find_member "$TMP/freedoom" "freedoom1.wad")
		if [ -n "$wad" ]; then
			put_file "Doom (DOOM)" "$wad" "freedoom1.wad"
		else
			skip DOOM "zip had no freedoom1.wad"
		fi
	else
		skip DOOM "unzip failed"
	fi
else
	skip DOOM "download failed (Freedoom v0.13.0)"
fi

# ScummVM — Beneath a Steel Sky floppy, officially redistributable
if fetch "https://downloads.scummvm.org/frs/extras/Beneath%20a%20Steel%20Sky/BASS-Floppy-1.3.zip" \
	"$TMP/bass.zip" 300; then
	if put_zip "ScummVM (SCUMMVM)" "$TMP/bass.zip"; then
		:
	else
		skip SCUMMVM "unzip failed (BASS floppy)"
	fi
else
	skip SCUMMVM "download failed (BASS floppy 1.3)"
fi

# Pico-8 already ships Splore from the image.
skip PICO "Splore is already installed by the session"

# --- systems requested for live test ---

# GBA — jsmolka ARM test ROM (MIT)
try_file GBA "Game Boy Advance (GBA)" "arm.gba" \
	"https://github.com/jsmolka/gba-tests/raw/master/arm/arm.gba"

# SFC — krom / Peter Lemon HelloWorld (author binary in-tree)
try_file SFC "Super Nintendo Entertainment System (SFC)" "HelloWorld.sfc" \
	"https://raw.githubusercontent.com/PeterLemon/SNES/master/HelloWorld/HelloWorld.sfc"

# Master System / Game Gear — krom HelloWorld
try_file MS "Sega Master System (MS)" "HelloWorld.sms" \
	"https://raw.githubusercontent.com/PeterLemon/SMS/master/VDP/HelloWorld/HelloWorld.sms"
try_file GG "Sega Game Gear (GG)" "HelloWorld.gg" \
	"https://raw.githubusercontent.com/PeterLemon/GG/master/VDP/HelloWorld/HelloWorld.gg"

# N64 — krom HelloWorld CPU 320x240
try_file N64 "Nintendo 64 (N64)" "HelloWorldCPU16BPP320X240.N64" \
	"https://raw.githubusercontent.com/PeterLemon/N64/master/HelloWorld/16BPP/HelloWorldCPU320x240/HelloWorldCPU16BPP320X240.N64" \
	300

# NDS — devkitPro hbmenu (homebrew menu ROM)
try_zip_member NDS "Nintendo DS (NDS)" "hbmenu.nds" \
	"https://github.com/devkitPro/nds-hb-menu/releases/download/v0.11.0/hbmenu-0.11.0.zip" \
	"*.nds" 300

# PCE / MSX — krom HelloWorld
try_file PCE "PC Engine (PCE)" "HelloWorld.pce" \
	"https://raw.githubusercontent.com/PeterLemon/PCE/master/VDC/HelloWorld/HelloWorld.pce"
try_file MSX "MSX (MSX)" "HelloWorld.rom" \
	"https://raw.githubusercontent.com/PeterLemon/MSX/master/HelloWorld/HelloWorld.rom"

# Lynx — 42Bastian BLL overlay demo
try_file LYNX "Atari Lynx (LYNX)" "overlay.lnx" \
	"https://raw.githubusercontent.com/42Bastian/new_bll/master/demos/overlay/overlay.lnx"

# SG-1000 — ZEXALL SMS (author says TMS9918 / SG-1000 path works)
try_zip_member SG1000 "Sega SG-1000 (SG1000)" "zexall.sg" \
	"https://github.com/maxim-zhao/zexall-sms/releases/download/v0.21/ZEXALL-SMS-0.21.zip" \
	"zexall.sms"

# Pokemon Mini — DarkFader Hello World (official pokemon-mini.net freeware)
try_zip_member PKM "Pokemon Mini (PKM)" "hello.min" \
	"https://www.pokemon-mini.net/download/hello-world-demo/?wpdmdl=3442" \
	"hello.min"

# Atari ST — EmuTOS boot floppy (GPL)
try_zip_member ST "Atari ST (ST)" "emutos.st" \
	"https://downloads.sourceforge.net/project/emutos/emutos/1.4/emutos-floppy-1.4.zip" \
	"*.st" 300

# MAME — Gridlee, granted for non-commercial use from mamedev.org only
if fetch "https://www.mamedev.org/roms/gridlee/gridlee.zip" "$TMP/gridlee.zip"; then
	put_file "MAME (MAME)" "$TMP/gridlee.zip" "gridlee.zip"
	put_file "FBNeo (FBNEO)" "$TMP/gridlee.zip" "gridlee.zip"
else
	skip MAME "download failed (mamedev.org gridlee.zip)"
	skip FBNEO "same gridlee.zip missing"
fi

# DOS — Digger (freeware, original author / digger.org)
try_zip_member DOS "DOS (DOS)" "digger.exe" \
	"https://www.digger.org/digger.zip" \
	"*.exe"

# TIC-80 — original size-coded demo cart (not a commercial remake)
try_file TIC "TIC-80 (TIC)" "demo.tic" \
	"https://raw.githubusercontent.com/annejan/outline26-claude-tic80/main/demo.tic"

# Pico-8 fake-08 — reuse Splore if present, else a tiny original cart
p8dir="$DEST/Pico-8 fake-08 (P8)"
splore=$(find "$DEST/Pico-8 (PICO)" -iname 'Splore.p8' 2>/dev/null | head -n 1)
if [ -n "$splore" ]; then
	mkdir -p "$p8dir"
	cp -f "$splore" "$p8dir/Splore.p8"
	log "OK Pico-8 fake-08 (P8) <- Splore.p8"
else
	mkdir -p "$p8dir"
	printf '%s\n' \
		'pico-8 cartridge // http://www.pico-8.com' \
		'version 8' \
		'__lua__' \
		'function _draw()' \
		' cls()' \
		' print("zlyme",32,64,11)' \
		'end' \
		> "$p8dir/zlyme.p8"
	log "OK Pico-8 fake-08 (P8) <- zlyme.p8 (original)"
fi

# EasyRPG TestGame (GPL) — zip is large; host wifi is fine, device needs a long timeout
if fetch "https://github.com/EasyRPG/TestGame/archive/refs/heads/master.zip" \
	"$TMP/easyrpg.zip" 900; then
	mkdir -p "$TMP/easyrpg"
	if unzip_into "$TMP/easyrpg.zip" "$TMP/easyrpg"; then
		tg=$(find "$TMP/easyrpg" -type d -name 'TestGame-2000' | head -n 1)
		if [ -n "$tg" ] && zip_dir "$tg" "$TMP/TestGame-2000.zip"; then
			put_file "RPG Maker 2000-2003 (EASYRPG)" "$TMP/TestGame-2000.zip" "TestGame-2000.zip"
		else
			skip EASYRPG "zip had no TestGame-2000"
		fi
	else
		skip EASYRPG "unzip failed"
	fi
else
	skip EASYRPG "download failed (TestGame archive)"
fi

# Windows — PuTTY x64 (MIT). Wine here is Kron4ek amd64 under box64,
# not aarch64 PE.
try_file WINE "Windows (WINE)" "putty.exe" \
	"https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe"

# PS2 — wLaunchELF (ps2homebrew). Commercial ISOs are not pinned.
try_file PS2 "Sony PlayStation 2 (PS2)" "wLaunchELF.elf" \
	"https://github.com/ps2homebrew/wLaunchELF/releases/download/latest/BOOT.ELF"

# GameCube — cubeboot.dol (GPL IPL helper). Direct asset, not Swiss's 7z.
try_file GC "Nintendo GameCube (GC)" "cubeboot.dol" \
	"https://github.com/OffBroadway/cubeboot/releases/download/v0.1.4/cubeboot.dol"

# Wii — Nintendont loader.dol (GPL), in-tree binary.
try_file WII "Nintendo Wii (WII)" "Nintendont.dol" \
	"https://github.com/FIX94/Nintendont/raw/master/loader/loader.dol" \
	300

# Expected skips: no pinned redistributable ROM (disc images / commercial / no binary).
skip GBC "no separate freeware cart pinned (GB homebrew can live in GBC)"
skip MD "already live-tested when a cart is present; no extra homebrew pin"
skip 32X "no small legal 32X homebrew binary pinned"
skip PS "commercial discs only"
skip PSP "commercial / no pinned homebrew"
skip DC "no small legal CDI/GDI pinned"
skip NGP "examples are source-only; no .ngp binary pinned"
skip WS "Wonderful/backup-tool binaries are not a stable raw URL"
skip VB "no small legal .vb binary pinned"
skip A26 "no redistributable 2600 homebrew binary pinned"
skip A5200 "no redistributable 5200 homebrew URL pinned"
skip A78 "no redistributable 7800 homebrew URL pinned"
skip A800 "no redistributable Atari 8-bit homebrew URL pinned"
skip COLECO "CVBasic examples are source-only"
skip INTV "jzintv examples are not a single stable ROM URL"
skip O2 "no redistributable Odyssey 2 homebrew URL pinned"
skip SGX "no redistributable SuperGrafx homebrew URL pinned"
skip VEC "no redistributable Vectrex homebrew URL pinned"
skip 3DO "commercial discs only"
skip NEOCD "commercial discs only"
skip SATURN "Jo Engine samples ship without a ROM asset"
skip AMIGA "HelloAmi repo has no prebuilt ADF"
skip PORTS "PortMaster games are installed on device"
skip MKXPZ "RTP-based games are not redistributable here"
skip OPENBOR "no original-asset .pak (Beats of Rage uses SNK sprites)"
skip DAPHNE "no free laserdisc dump"

log "done"
exit 0
