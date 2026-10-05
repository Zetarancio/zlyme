#!/bin/sh
# post-build.sh asserts only the packages the active config selects.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
post=$ROOT/board/my355/post-build.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

seed_target() {
	t=$1
	mkdir -p \
		"$t/lib/modules/7.0.2/updates" \
		"$t/lib/firmware/rtl_bt" \
		"$t/usr/sbin" "$t/usr/bin" "$t/usr/lib" "$t/usr/share/zlyme" \
		"$t/sbin" "$t/bin" "$t/etc/modprobe.d" "$t/etc/init.d" \
		"$t/var/lib"
	: > "$t/lib/modules/7.0.2/updates/8733bu.ko"
	: > "$t/lib/modules/7.0.2/updates/rtl8733bu_power.ko"
	printf '%s\n' 'softdep rtl8733bu_power post: 8733bu' \
		> "$t/lib/modules/7.0.2/modules.softdep"
	printf 'fw\n' > "$t/lib/firmware/rtl_bt/rtl8723fu_fw.bin"
	printf 'cfg\n' > "$t/lib/firmware/rtl_bt/rtl8723fu_config.bin"
	printf 'reg\n' > "$t/lib/firmware/regulatory.db"
	: > "$t/usr/sbin/sshd"
	: > "$t/usr/bin/scp"
	: > "$t/usr/sbin/zlyme-jackd"
	printf '%s\n' '#!/bin/sh' 'exit 0' > "$t/bin/busybox"
	chmod 0755 "$t/bin/busybox"
	ln -s ../../bin/busybox "$t/usr/bin/flock"
	: > "$t/usr/bin/kmod"
	ln -s ../usr/bin/kmod "$t/sbin/modprobe"
	printf '%s\n' 'NAME="Buildroot"' > "$t/usr/lib/os-release"
	cp "$ROOT/board/my355/fsoverlay/usr/share/zlyme/device.conf" \
		"$t/usr/share/zlyme/device.conf"
	printf '%s\n' 'blacklist panfrost' > "$t/etc/modprobe.d/zlyme-gpu.conf"
	: > "$t/etc/fstab"
	for l in cache log spool tmp run lock; do
		ln -s /tmp "$t/var/$l"
	done
	ln -s /tmp "$t/var/lib/dbus"
}

minimal_cfg=$work/minimal.config
cat > "$minimal_cfg" <<'EOF'
BR2_PACKAGE_KMOD=y
BR2_PACKAGE_RTL8733BU=y
BR2_PACKAGE_RTL8733BU_POWER=y
BR2_PACKAGE_RTL8723FU_FIRMWARE=y
BR2_PACKAGE_WIRELESS_REGDB=y
BR2_PACKAGE_OPENSSH=y
BR2_PACKAGE_ZLYME_JACKD=y
BR2_PACKAGE_NEXTUI_PLATFORM="my355"
EOF

seed_target "$work/minimal"
env -u HOST_DIR \
	BR2_CONFIG="$minimal_cfg" \
	ZLYME_IMAGE_DATE=2026-10-04 \
	bash "$post" "$work/minimal" >"$work/minimal.out" 2>"$work/minimal.err"
if [ -e "$work/minimal/etc/modprobe.d/zlyme-gpu.conf" ]; then
	echo "minimal image kept the panfrost blacklist" >&2
	exit 1
fi
if [ -e "$work/minimal/usr/sbin/zlyme-keylidmon" ]; then
	echo "fixture unexpectedly grew keylidmon" >&2
	exit 1
fi

product_cfg=$work/product.config
cat "$minimal_cfg" > "$product_cfg"
cat >> "$product_cfg" <<'EOF'
BR2_PACKAGE_MIYOO_FLIP_GAMEPAD=y
BR2_PACKAGE_ZLYME_KEYLIDMON=y
BR2_PACKAGE_NEXTUI=y
BR2_PACKAGE_GPUDRIVER=y
BR2_PACKAGE_LIBMALI=y
EOF
seed_target "$work/product"
if env -u HOST_DIR \
	BR2_CONFIG="$product_cfg" \
	ZLYME_IMAGE_DATE=2026-10-04 \
	bash "$post" "$work/product" >"$work/product.out" 2>"$work/product.err"
then
	echo "product config passed without gamepad, keylidmon, or paks" >&2
	exit 1
fi
if ! grep -q 'miyoo-flip-gamepad.ko is missing' "$work/product.err"; then
	echo "product failure did not name the gamepad module" >&2
	cat "$work/product.err" >&2
	exit 1
fi
if ! grep -q 'zlyme-keylidmon is missing' "$work/product.err"; then
	echo "product failure did not name keylidmon" >&2
	exit 1
fi
if [ ! -f "$work/product/etc/modprobe.d/zlyme-gpu.conf" ]; then
	echo "product image dropped the panfrost blacklist" >&2
	exit 1
fi

seed_target "$work/closed"
if env -u HOST_DIR -u BR2_CONFIG \
	ZLYME_IMAGE_DATE=2026-10-04 \
	bash "$post" "$work/closed" >"$work/closed.out" 2>"$work/closed.err"
then
	echo "missing BR2_CONFIG skipped product assertions" >&2
	exit 1
fi
grep -q 'miyoo-flip-gamepad.ko is missing' "$work/closed.err"

seed_target "$work/noflock"
rm -f "$work/noflock/usr/bin/flock"
if env -u HOST_DIR \
	BR2_CONFIG="$minimal_cfg" \
	ZLYME_IMAGE_DATE=2026-10-04 \
	bash "$post" "$work/noflock" >"$work/noflock.out" 2>"$work/noflock.err"
then
	echo "missing busybox flock was accepted" >&2
	exit 1
fi
grep -q 'busybox flock applet is missing' "$work/noflock.err"

echo "post-build config ok"
