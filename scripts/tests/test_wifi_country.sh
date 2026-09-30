#!/bin/sh
# Host checks for zlyme-wifi country. No radio and no /storage writes.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
WIFI="$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-wifi"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bin=$work/bin
mkdir -p "$bin"
log=$work/mock.log
: >"$log"

cat >"$bin/iw" <<'EOF'
#!/bin/sh
printf 'iw %s\n' "$*" >> "$ZLYME_WIFI_MOCK_LOG"
exit "${ZLYME_IW_STATUS:-0}"
EOF
cat >"$bin/wpa_cli" <<'EOF'
#!/bin/sh
printf 'wpa_cli %s\n' "$*" >> "$ZLYME_WIFI_MOCK_LOG"
if [ "${ZLYME_WPA_STATUS:-0}" = 0 ]; then
	echo OK
	exit 0
fi
echo FAIL
exit 1
EOF
chmod 0755 "$bin/iw" "$bin/wpa_cli"

run() {
	PATH="$bin:$PATH" ZLYME_WPA_CONF="$1" ZLYME_WIFI_MOCK_LOG="$log" \
		ZLYME_WIFI_ACTIVE="${ZLYME_WIFI_ACTIVE:-0}" \
		ZLYME_IW_STATUS="${ZLYME_IW_STATUS:-0}" \
		ZLYME_WPA_STATUS="${ZLYME_WPA_STATUS:-0}" \
		"$WIFI" country ${2+"$2"}
}

base() {
	cat >"$1" <<'EOF'
# keep me
ctrl_interface=/var/run/wpa_supplicant
update_config=1
ap_scan=1

network={
	ssid="Cafe"
	psk="secret-value"
	key_mgmt=WPA-PSK
}
EOF
}

netblock() {
	awk '
		BEGIN { on = 0 }
		{
			if ($0 ~ /^[ \t]*network[ \t]*=[ \t]*\{/)
				on = 1
			if (on)
				print
		}
	' "$1"
}

conf=$work/wpa.conf
base "$conf"
got=$(run "$conf")
[ "$got" = "00" ]

# A lowercase global country is reported in uppercase. It stays outside the network block.
sed -i 's/^ap_scan=1$/ap_scan=1\ncountry=it/' "$conf"
got=$(run "$conf")
[ "$got" = "IT" ]

net_before=$(netblock "$conf")
ZLYME_WIFI_ACTIVE=0 run "$conf" IT >/dev/null
got=$(run "$conf")
[ "$got" = "IT" ]
[ "$(grep -c '^country=' "$conf")" = 1 ]
grep -qx 'country=IT' "$conf"
[ "$(netblock "$conf")" = "$net_before" ]
[ ! -s "$log" ]

# Replace US with GB and collapse a duplicate.
cat >"$conf" <<'EOF'
ctrl_interface=/var/run/wpa_supplicant
country=US
update_config=1
country=FR
ap_scan=1
network={
	ssid="Cafe"
	psk="secret-value"
}
EOF
net_before=$(netblock "$conf")
: >"$log"
ZLYME_WIFI_ACTIVE=0 run "$conf" gb >/dev/null
[ "$(grep -c '^country=' "$conf")" = 1 ]
grep -qx 'country=GB' "$conf"
grep -qx 'ctrl_interface=/var/run/wpa_supplicant' "$conf"
grep -qx 'update_config=1' "$conf"
grep -qx 'ap_scan=1' "$conf"
[ "$(netblock "$conf")" = "$net_before" ]

ZLYME_WIFI_ACTIVE=0 run "$conf" 00 >/dev/null
[ "$(grep -c '^country=' "$conf" || true)" = 0 ]
got=$(run "$conf")
[ "$got" = "00" ]
grep -q 'ssid="Cafe"' "$conf"
grep -q 'psk="secret-value"' "$conf"

for bad in EU I ITA I1 'IT; reboot' ' IT' ''; do
	base "$conf"
	before=$(cat "$conf")
	if ZLYME_WIFI_ACTIVE=0 run "$conf" "$bad" >/dev/null 2>&1; then
		echo "accepted bad country: $bad" >&2
		exit 1
	fi
	[ "$(cat "$conf")" = "$before" ]
done

for good in it IT gb 00; do
	base "$conf"
	ZLYME_WIFI_ACTIVE=0 run "$conf" "$good" >/dev/null
done

# Active radio: persist, then iw and wpa_cli. A failed hint keeps the file.
base "$conf"
: >"$log"
ZLYME_WIFI_ACTIVE=1 run "$conf" IT >/dev/null
grep -qx 'country=IT' "$conf"
grep -qx 'iw reg set IT' "$log"
grep -q 'wpa_cli .* reconfigure' "$log"

: >"$log"
if ZLYME_WIFI_ACTIVE=1 ZLYME_IW_STATUS=1 run "$conf" GB >/dev/null 2>"$work/err"; then
	echo "runtime failure was success" >&2
	exit 1
fi
grep -q 'radio did not apply' "$work/err"
grep -qx 'country=GB' "$conf"
grep -qx 'iw reg set GB' "$log"
grep -q reconfigure "$log" && {
	echo "reconfigure ran after iw failed" >&2
	exit 1
}

# Inactive: persistence only.
base "$conf"
: >"$log"
ZLYME_WIFI_ACTIVE=0 run "$conf" US >/dev/null
grep -qx 'country=US' "$conf"
[ ! -s "$log" ]

echo "wifi country ok"
