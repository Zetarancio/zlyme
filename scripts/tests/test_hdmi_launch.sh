#!/bin/sh
# Launcher policy. This does not open a CRTC.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "hdmi-launch: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc -std=c11 -Wall -Wextra -Werror -D_GNU_SOURCE \
	-I"$ROOT/package/system/zlyme-hdmi" -I/usr/include/libdrm \
	-o "$work/zlyme-hdmi" \
	"$ROOT/package/system/zlyme-hdmi/zlyme-hdmi.c" \
	"$ROOT/package/system/zlyme-hdmi/hdmi_mode.c" \
	-ldrm

cat > "$work/fix" <<'EOF'
connector card=0 id=179 name=DSI-1 type=dsi connected=1
mode 640 480 60000 60 1
connector card=0 id=164 name=HDMI-A-1 type=hdmia connected=1
mode 1920 1080 60000 60 1
mode 1280 720 59940 60 0
EOF
off=$(ZLYME_HDMI_TRACE=1 "$work/zlyme-hdmi" export 2>"$work/off.err")
printf '%s\n' "$off" | grep -qx 'ZLYME_HDMI_ACTIVE=0' || fail "gate off was active"
grep -q 'drm-open' "$work/off.err" && fail "gate off opened DRM"
on=$(ZLYME_HDMI_720P=1 ZLYME_HDMI_TRACE=1 ZLYME_HDMI_FIXTURE=$work/fix \
	ZLYME_HDMI_MODE_PATH=$work/mode \
	"$work/zlyme-hdmi" export 2>"$work/on.err")
grep -q 'drm-open' "$work/on.err" && fail "fixture opened DRM"
printf '%s\n' "$on" | grep -q "ZLYME_HDMI_CONNECTOR_ID=164" || fail "connector id lost"
printf '%s\n' "$on" | grep -q "ZLYME_HDMI_REFRESH_HZ=59.940" || fail "59.94 was rounded in the policy"
printf '%s\n' "$on" | grep -q "ZLYME_HDMI_MONITOR=2" || fail "monitor index lost"
printf '%s\n' "$on" | grep -q "ZLYME_HDMI_SDL_INDEX=1" || fail "59.94 Hz lost its mode index"
grep -q 'connector_id=164' "$work/mode" || fail "mode file lost the connector"

# Empty list.
printf '%s\n' 'connector card=0 id=164 name=HDMI-A-1 type=hdmia connected=0' > "$work/empty"
empty=$(ZLYME_HDMI_720P=1 ZLYME_HDMI_FIXTURE=$work/empty "$work/zlyme-hdmi" export)
printf '%s\n' "$empty" | grep -qx 'ZLYME_HDMI_ACTIVE=0' || fail "disconnected HDMI stayed active"

# RetroArch session file, and a user override.
mkdir -p "$work/cfg/retroarch" "$work/bios" "$work/saves" "$work/sys"
printf 'core\n' > "$work/sys/mgba_libretro.so"
: > "$work/bios/.zlyme-ready"
: > "$work/cfg/retroarch/retroarch.cfg"
eval "$on"
out=$(
	XDG_CONFIG_HOME=$work/cfg \
		BIOS_PATH=$work/bios \
		SAVES_PATH=$work/saves \
		ZLYME_HDMI_720P=1 \
		ZLYME_HDMI_SESSION=$ROOT/package/system/zlyme-hdmi/hdmi-session.sh \
		ZLYME_HDMI_BIN=$work/zlyme-hdmi \
		ZLYME_HDMI_FIXTURE=$work/fix \
		ZLYME_HDMI_MODE_PATH=$work/mode2 \
		ZLYME_HDMI_RA_CFG=$work/hdmi.cfg \
		ZLYME_RA_DRY_RUN=1 \
		ZLYME_RA_SYSTEM_CORES=$work/sys \
		ZLYME_RA_USER_CORES=$work/sys \
		ZLYME_RA_MINUI=$work/minui.cfg \
		ZLYME_RA_SAVES=$work/saves.cfg \
		sh "$ROOT/package/system/nextui/zlyme/ra-run.sh" -L "$work/sys/mgba_libretro.so" "$work/game.gb"
)
grep -q 'video_fullscreen_x = "1280"' "$work/hdmi.cfg" || fail "RetroArch session omitted 720p"
grep -q 'video_refresh_rate = "59.940"' "$work/hdmi.cfg" || fail "RetroArch session omitted 59.94"
grep -q 'video_monitor_index = "2"' "$work/hdmi.cfg" || fail "RetroArch session omitted the connector index"
grep -q 'video_aspect_ratio' "$work/hdmi.cfg" && fail "RetroArch session overrode aspect"
printf '%s\n' "$out" | grep -q "$work/hdmi.cfg" || fail "session file was not appended"
before=$(cksum "$work/cfg/retroarch/retroarch.cfg")
printf 'video_fullscreen_x = "1920"\n' > "$work/cfg/retroarch/retroarch.cfg"
rm -f "$work/hdmi.cfg"
XDG_CONFIG_HOME=$work/cfg \
	BIOS_PATH=$work/bios \
	SAVES_PATH=$work/saves \
	ZLYME_HDMI_720P=1 \
	ZLYME_HDMI_SESSION=$ROOT/package/system/zlyme-hdmi/hdmi-session.sh \
	ZLYME_HDMI_BIN=$work/zlyme-hdmi \
	ZLYME_HDMI_FIXTURE=$work/fix \
	ZLYME_HDMI_MODE_PATH=$work/mode3 \
	ZLYME_HDMI_RA_CFG=$work/hdmi.cfg \
	ZLYME_RA_DRY_RUN=1 \
	ZLYME_RA_SYSTEM_CORES=$work/sys \
	ZLYME_RA_USER_CORES=$work/sys \
	ZLYME_RA_MINUI=$work/minui.cfg \
	ZLYME_RA_SAVES=$work/saves.cfg \
	sh "$ROOT/package/system/nextui/zlyme/ra-run.sh" -L "$work/sys/mgba_libretro.so" "$work/game.gb" >/dev/null
[ ! -s "$work/hdmi.cfg" ] || fail "user fullscreen size was replaced"
after=$(cksum "$work/cfg/retroarch/retroarch.cfg")
[ "$before" != "$after" ] || fail "test did not change the user file itself"
grep -q 'video_fullscreen_x = "1920"' "$work/cfg/retroarch/retroarch.cfg" \
	|| fail "user configuration was rewritten"

# Gate off does not append.
rm -f "$work/hdmi.cfg"
: > "$work/cfg/retroarch/retroarch.cfg"
XDG_CONFIG_HOME=$work/cfg \
	BIOS_PATH=$work/bios \
	SAVES_PATH=$work/saves \
	ZLYME_RA_DRY_RUN=1 \
	ZLYME_RA_SYSTEM_CORES=$work/sys \
	ZLYME_RA_USER_CORES=$work/sys \
	ZLYME_RA_MINUI=$work/minui.cfg \
	ZLYME_RA_SAVES=$work/saves.cfg \
	ZLYME_HDMI_RA_CFG=$work/hdmi.cfg \
	sh "$ROOT/package/system/nextui/zlyme/ra-run.sh" -L "$work/sys/mgba_libretro.so" "$work/game.gb" >/dev/null
[ ! -s "$work/hdmi.cfg" ] || fail "gate off wrote a RetroArch mode"

grep -q 'zlyme_hdmi_apply' "$ROOT/package/system/nextui/zlyme/pak-launch.sh" \
	|| fail "pak launch does not apply the policy"
grep -q 'zlyme_hdmi_apply' "$ROOT/package/system/nextui/nextui-session" \
	|| fail "the frontend session does not apply the policy"
grep -q 'WESTON_CFG' "$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-weston-run" \
	|| fail "Weston has no gated mode file"
grep -q 'QT_QPA_EGLFS_KMS_CONFIG' "$ROOT/package/emulators/aethersx2/start_aethersx2.sh" \
	|| fail "AetherSX2 has no gated KMS config"
grep -q '/var/run/drmMode' "$ROOT/package/emulators/dolphin-emu/start_dolphin.sh" \
	&& fail "Dolphin's launcher writes a raw mode index"
cc_probe=$ROOT/output/host/bin/aarch64-buildroot-linux-gnu-gcc
if [ -x "$cc_probe" ]; then
	"$cc_probe" -Wall -Wextra -Werror \
		-I"$ROOT/output/host/aarch64-buildroot-linux-gnu/sysroot/usr/include/SDL2" \
		-o "$work/sdl-kms-probe" "$ROOT/scripts/tests/sdl_kms_probe.c" -lSDL2 \
		|| fail "SDL probe did not link"
fi
echo "hdmi launch ok"
