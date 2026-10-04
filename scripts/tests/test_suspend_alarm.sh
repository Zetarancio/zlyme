#!/bin/sh
# Suspend preserves an externally configured RTC alarm because the
# production helper never touches the RTC alarm interface.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
helper=$ROOT/package/system/nextui/zlyme/suspend

check_helper() {
	file=$1
	if grep -q wakealarm "$file"; then
		echo "suspend helper references wakealarm: $file" >&2
		return 1
	fi
	if grep -q '/sys/class/rtc/rtc0' "$file"; then
		echo "suspend helper has rtc0 policy: $file" >&2
		return 1
	fi
	if grep -E 'echo[[:space:]]+\+[0-9]+' "$file" >/dev/null; then
		echo "suspend helper programs a relative RTC alarm: $file" >&2
		return 1
	fi
	if grep -q 86400 "$file"; then
		echo "suspend helper still mentions the 24-hour test alarm: $file" >&2
		return 1
	fi
	awk '
		/^[ \t]*sync[ \t]*$/ && !sync_line { sync_line = NR }
		/^[ \t]*echo mem > \/sys\/power\/state[ \t]*$/ && !mem_line { mem_line = NR }
		END {
			if (!sync_line || !mem_line || !(sync_line < mem_line)) exit 1
		}
	' "$file"
}

check_helper "$helper"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/clear.sh" <<'EOF'
#!/bin/sh
echo 0 > /sys/class/rtc/rtc0/wakealarm
sync
echo mem > /sys/power/state
EOF
if check_helper "$work/clear.sh"; then
	echo "a helper that clears wakealarm was accepted" >&2
	exit 1
fi

cat > "$work/arm.sh" <<'EOF'
#!/bin/sh
echo +86400 > /sys/class/rtc/rtc0/wakealarm
sync
echo mem > /sys/power/state
EOF
if check_helper "$work/arm.sh"; then
	echo "a helper that arms a relative alarm was accepted" >&2
	exit 1
fi

echo "suspend alarm ok"
