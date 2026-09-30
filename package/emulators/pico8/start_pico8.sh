#!/bin/sh
# PICO-8 is not redistributable. MinUI layout is Bios/PICO/pico8_64
# plus pico8.dat. The binary is not loaded from the ROM folder.
#
# A path whose name contains "splore" starts Splore instead of -run.
# Dummy Splore.p8 stays in the rom folder; -root_path is that folder
# (minui-pico-8-pak). XDG is under Pico-8-native so BBS state is not
# written into OS .config.

STATIC_BIN="pico8_64"
SDCARD="${SDCARD_PATH:-/storage}"
BIOS="${BIOS_PATH:-$SDCARD/Bios}"
SHARED="${SHARED_USERDATA_PATH:-$SDCARD/.config/nextui/shared}"
HOME_DIR="${SHARED}/Pico-8-native"
ROM="$1"
DB="${SDL_GAMECONTROLLERCONFIG_FILE:-/usr/lib/gamecontrollerdb.txt}"

# A runtime is valid only when pico8_64 and pico8.dat are both present.
# Splore's dummy ROM lives on the main card, so the ROM library's BIOS
# is not the only place the commercial files may be. Ordinary emulators
# still use only the ROM library. This search does not move files.
#
# ZLYME_PICO_LIBRARIES and ZLYME_PICO_DRY=1 are test seams.

GAME_DIR=""
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
	GAME_DIR=$(dirname "$ROM")
fi

pair_ok() {
	[ -f "$1/$STATIC_BIN" ] && [ -f "$1/pico8.dat" ]
}

tried=$(mktemp)
trap 'rm -f "$tried"' EXIT
LAUNCH_DIR=""

consider() {
	d=$1
	[ -n "$d" ] || return 1
	if grep -Fxq -- "$d" "$tried" 2>/dev/null; then
		return 1
	fi
	printf '%s\n' "$d" >> "$tried"
	if pair_ok "$d"; then
		LAUNCH_DIR=$d
		return 0
	fi
	return 1
}

consider_bios() {
	root=$1
	[ -n "$root" ] || return 1
	consider "$root/PICO" && return 0
	consider "$root/PICO/aarch64" && return 0
	consider "$root/PICO-8" && return 0
	consider "$root" && return 0
	return 1
}

consider_bios "$BIOS" || true

libs=${ZLYME_PICO_LIBRARIES:-/run/zlyme/libraries}
if [ -z "$LAUNCH_DIR" ] && [ -r "$libs" ]; then
	while IFS= read -r lib; do
		[ -n "$lib" ] || continue
		consider_bios "$lib/Bios" && break
	done < "$libs"
elif [ -z "$LAUNCH_DIR" ]; then
	consider_bios /storage/Bios || true
fi

if [ -z "$LAUNCH_DIR" ]; then
	echo "pico8: put pico8_64 and pico8.dat in Bios/PICO/ on the main card, second SD, or another mounted library" >&2
	exit 1
fi

if [ "${ZLYME_PICO_DRY:-}" = 1 ]; then
	printf 'LAUNCH_DIR=%s\n' "$LAUNCH_DIR"
	exit 0
fi

chmod 0755 "$LAUNCH_DIR/$STATIC_BIN" 2>/dev/null || true
mkdir -p "$HOME_DIR/carts" "$HOME_DIR/cdata" "$HOME_DIR/bbs" "$HOME_DIR/config" "$HOME_DIR/data"

# Splore BBS "cannot connect" is often missing CA certs; list update
# can still work. Prefer a writable rom folder for carts (sd2 ext4).
for ca in /etc/ssl/certs/ca-certificates.crt \
	/etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt; do
	if [ -f "$ca" ]; then
		export SSL_CERT_FILE="$ca"
		export CURL_CA_BUNDLE="$ca"
		export SSL_CERT_DIR=/etc/ssl/certs
		break
	fi
done
export HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$HOME_DIR/config"
export XDG_DATA_HOME="$HOME_DIR/data"

# Dummy Splore.p8 stays in the rom folder; -root_path is that folder
# (minui-pico-8-pak). An empty carts/ root broke BBS list update.

if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi
export SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT="${SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT:-0x045e/0x028e}"
export SDL_GAMECONTROLLERCONFIG_FILE="$DB"
if [ -z "${SDL_GAMECONTROLLERCONFIG:-}" ] && [ -f "$DB" ]; then
	SDL_GAMECONTROLLERCONFIG=$(grep -v '^#' "$DB" | grep 'Microsoft X-Box 360 pad' | head -n 1)
	export SDL_GAMECONTROLLERCONFIG
fi
# pak-input.sh hides the physical pad, so the virtual target is index 0.
joy=0

# ROCKNIX: pico8 reads sdl_controllers.txt next to the binary and under -home.
if [ -f "$DB" ]; then
	for dest in "$HOME_DIR/sdl_controllers.txt" "$LAUNCH_DIR/sdl_controllers.txt"; do
		cmp -s "$DB" "$dest" 2>/dev/null && continue
		cp -f "$DB" "$dest" 2>/dev/null || true
	done
fi

if [ -z "$GAME_DIR" ] || [ ! -d "$GAME_DIR" ]; then
	GAME_DIR="$SDCARD/Roms/Pico-8 (PICO)"
	mkdir -p "$GAME_DIR"
fi

# Splore's wget is PATH "wget URL -q -O file". Prefer the curl wrapper
# over BusyBox (no TLS) even if cwd is Bios/PICO.
export PATH="/usr/bin:/bin:${PATH:-/usr/bin}"

cd "$LAUNCH_DIR" || exit 1
# ROCKNIX runs the Pico-8 binary directly. The virtual xb360 pad is SDL
# joystick 0 and its d-pad is a hat, so Splore does not need a translator
# that grabs that pad.
if echo "$ROM" | grep -qi splore; then
	exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick 0 -splore
fi
exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick "$joy" -run "$ROM"
