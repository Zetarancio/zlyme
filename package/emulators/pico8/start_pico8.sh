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

# Older cards dropped the binary in Bios/. MinUI is Bios/PICO/.
mkdir -p "$BIOS/PICO"
for f in pico8_64 pico8.dat pico8_dyn; do
	if [ -e "$BIOS/$f" ] && [ ! -e "$BIOS/PICO/$f" ]; then
		mv "$BIOS/$f" "$BIOS/PICO/$f" 2>/dev/null || true
	fi
done

GAME_DIR=""
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
	GAME_DIR=$(dirname "$ROM")
fi

LAUNCH_DIR=""
set -- \
	"$BIOS/PICO" \
	"$BIOS/PICO/aarch64" \
	"$BIOS/PICO-8" \
	"$BIOS" \
	"/storage/Bios/PICO" \
	"/storage/Bios/PICO/aarch64" \
	"/storage/Bios"
for d in "$@"; do
	[ -n "$d" ] || continue
	if [ -x "$d/$STATIC_BIN" ] || [ -f "$d/$STATIC_BIN" ]; then
		LAUNCH_DIR=$d
		break
	fi
done

if [ -z "$LAUNCH_DIR" ]; then
	echo "pico8: put ${STATIC_BIN} and pico8.dat in ${BIOS}/PICO" >&2
	exit 1
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

export SDL_GAMECONTROLLERCONFIG_FILE="$DB"
export SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT="${SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT:-0x045e/0x028e}"
if [ -z "${SDL_GAMECONTROLLERCONFIG:-}" ] && [ -f "$DB" ]; then
	SDL_GAMECONTROLLERCONFIG=$(grep -v '^#' "$DB" | grep 'Microsoft X-Box 360 pad' | head -n 1)
	export SDL_GAMECONTROLLERCONFIG
fi
joy=0
if [ -r /usr/share/zlyme/virtpad-index.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/virtpad-index.sh
	joy=$(zlyme_virtpad_js_index)
	[ -n "$joy" ] || joy=0
fi

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
if echo "$ROM" | grep -qi splore; then
	killall -9 pico8-splore-pad 2>/dev/null || true
	if command -v pico8-splore-pad >/dev/null 2>&1; then
		exec pico8-splore-pad "./${STATIC_BIN}" \
			-home "$HOME_DIR" -root_path "$GAME_DIR" -joystick "$joy" -splore
	fi
	exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick "$joy" -splore
fi
exec "./${STATIC_BIN}" -home "$HOME_DIR" -root_path "$GAME_DIR" -joystick "$joy" -run "$ROM"
