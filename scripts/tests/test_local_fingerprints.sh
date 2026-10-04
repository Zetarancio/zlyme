#!/bin/sh
# Every SITE_METHOD=local package is fingerprinted, or explicitly excepted.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
build=$ROOT/build.sh
exc=$ROOT/scripts/tests/fingerprint-exceptions.txt
missing=0

while IFS= read -r mk; do
	if ! grep -Eq '^[[:space:]]*[A-Za-z0-9_]*SITE_METHOD[[:space:]]*=[[:space:]]*local[[:space:]]*$' "$mk"; then
		continue
	fi
	dir=$(basename "$(dirname "$mk")")
	if grep -Eq "^[[:space:]]*refresh_compiled_package[[:space:]]+${dir}([[:space:]]|$)" "$build"; then
		continue
	fi
	if awk -F '\t' -v pkg="$dir" '
		/^[[:space:]]*#/ || NF == 0 { next }
		$1 == pkg && $2 ~ /[^[:space:]]/ { found = 1 }
		END { exit found ? 0 : 1 }
	' "$exc"; then
		continue
	fi
	echo "local package ${dir} has no fingerprint and no exception rationale" >&2
	missing=1
done <<EOF
$(find "$ROOT/package" -name '*.mk' -print)
EOF

if [ "$missing" -ne 0 ]; then
	exit 1
fi

# The eight packages that used to be omitted must be calls, not exceptions.
for dir in zlyme-input zlyme-jackd miyoo-flip-gamepad rk3568-dmc \
	rtl8733bu-power gpudriver pico8 rtl8723fu-firmware
do
	grep -Eq "^[[:space:]]*refresh_compiled_package[[:space:]]+${dir}([[:space:]]|$)" "$build" || {
		echo "expected fingerprint for ${dir}" >&2
		exit 1
	}
done

echo "local fingerprints ok"
