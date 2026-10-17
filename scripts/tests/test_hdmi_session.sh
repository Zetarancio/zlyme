#!/bin/sh
# The HDMI policy must be visible to a child, not only to the shell
# that eval'd zlyme-hdmi. This does not open a CRTC.
# shellcheck disable=SC1007
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fail() { echo "hdmi-session: $*" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cc -std=c11 -Wall -Wextra -Werror -D_GNU_SOURCE \
	-I"$ROOT/package/system/zlyme-hdmi" -I/usr/include/libdrm \
	-o "$work/zlyme-hdmi" \
	"$ROOT/package/system/zlyme-hdmi/zlyme-hdmi.c" \
	"$ROOT/package/system/zlyme-hdmi/hdmi_mode.c" \
	-ldrm

cat > "$work/fix" <<'EOF'
connector card=0 id=56 name=HDMI-A-1 type=hdmia connected=1
mode 1920 1080 60000 60 0
mode 1280 720 60000 60 0
connector card=0 id=59 name=DSI-1 type=dsi connected=1
mode 640 480 60000 60 1
EOF

cat > "$work/apply.sh" <<EOF
#!/bin/sh
. "$ROOT/package/system/zlyme-hdmi/hdmi-session.sh"
zlyme_hdmi_apply
exec sh -c 'printf "ACTIVE=%s\\nW=%s\\nH=%s\\nSDLC=%s\\nSDLI=%s\\nHZ=%s\\n" "\${ZLYME_HDMI_ACTIVE-}" "\${ZLYME_HDMI_WIDTH-}" "\${ZLYME_HDMI_HEIGHT-}" "\${ZLYME_HDMI_SDL_CONNECTOR-}" "\${ZLYME_HDMI_SDL_INDEX-}" "\${ZLYME_HDMI_REFRESH_HZ-}"'
EOF
chmod 755 "$work/apply.sh"

on=$(
	ZLYME_HDMI_720P=1 \
	ZLYME_HDMI_BIN="$work/zlyme-hdmi" \
	ZLYME_HDMI_FIXTURE="$work/fix" \
	ZLYME_HDMI_MODE_PATH="$work/hdmi.mode" \
	"$work/apply.sh"
)
printf '%s\n' "$on" | grep -qx 'ACTIVE=1' || fail "child missed ACTIVE: $on"
printf '%s\n' "$on" | grep -qx 'W=1280' || fail "child missed width: $on"
printf '%s\n' "$on" | grep -qx 'H=720' || fail "child missed height: $on"
printf '%s\n' "$on" | grep -qx 'SDLC=56' || fail "child missed connector: $on"
printf '%s\n' "$on" | grep -qx 'SDLI=1' || fail "child missed index: $on"
printf '%s\n' "$on" | grep -qx 'HZ=60.000' || fail "child missed refresh: $on"

off=$(
	env -u ZLYME_HDMI_720P \
	ZLYME_HDMI_BIN="$work/zlyme-hdmi" \
	ZLYME_HDMI_FIXTURE="$work/fix" \
	ZLYME_HDMI_MODE_PATH="$work/off.mode" \
	"$work/apply.sh"
)
printf '%s\n' "$off" | grep -qx 'ACTIVE=0' || fail "disabled child ACTIVE: $off"
printf '%s\n' "$off" | grep -qx 'W=' || fail "disabled child kept width: $off"
printf '%s\n' "$off" | grep -qx 'SDLC=' || fail "disabled child kept connector: $off"

cat > "$work/stale.sh" <<EOF
#!/bin/sh
. "$ROOT/package/system/zlyme-hdmi/hdmi-session.sh"
zlyme_hdmi_apply
ZLYME_HDMI_BIN=/bin/false
zlyme_hdmi_apply
exec sh -c 'printf "ACTIVE=%s\\nW=%s\\n" "\${ZLYME_HDMI_ACTIVE-}" "\${ZLYME_HDMI_WIDTH-}"'
EOF
chmod 755 "$work/stale.sh"
stale=$(
	ZLYME_HDMI_720P=1 \
	ZLYME_HDMI_BIN="$work/zlyme-hdmi" \
	ZLYME_HDMI_FIXTURE="$work/fix" \
	ZLYME_HDMI_MODE_PATH="$work/stale.mode" \
	"$work/stale.sh"
)
printf '%s\n' "$stale" | grep -qx 'ACTIVE=0' || fail "failed query kept ACTIVE: $stale"
printf '%s\n' "$stale" | grep -qx 'W=' || fail "failed query kept width: $stale"

mkdir -p "$work/blocked"
if ZLYME_HDMI_720P=1 \
	ZLYME_HDMI_FIXTURE=$work/fix \
	ZLYME_HDMI_MODE_PATH=$work/blocked \
	"$work/zlyme-hdmi" export >"$work/out" 2>"$work/err"
then
	grep -q 'mode file was not written' "$work/err" || fail "mode write failure was silent"
	grep -q '^ZLYME_HDMI_ACTIVE=1$' "$work/out" || fail "mode write failure dropped the policy"
else
	fail "mode write failure aborted the policy"
fi

if ! "$work/zlyme-hdmi" export >"$work/offout" 2>"$work/offerr"; then
	fail "disabled policy failed"
fi
grep -q '^ZLYME_HDMI_ACTIVE=0$' "$work/offout" || fail "disabled policy was not inactive"
echo "hdmi session ok"
