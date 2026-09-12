#!/usr/bin/env bash
# Fail the build if required pieces are missing from the target.

set -euo pipefail

TARGET_DIR="${1:?post-build.sh: expected TARGET_DIR as the first argument}"

fail=0
note() { echo "post-build: $*" >&2; fail=1; }
info() { echo "post-build: $*" >&2; }

shopt -s nullglob
moddirs=("${TARGET_DIR}"/lib/modules/*/)
shopt -u nullglob

if [ ${#moddirs[@]} -ne 1 ]; then
	note "expected exactly one /lib/modules/<release>, found ${#moddirs[@]}"
else
	moddir="${moddirs[0]}"
	for m in 8733bu rtl8733bu_power rocknix-singleadc-joypad; do
		found=$(find "${moddir}" -name "${m}.ko" -print -quit)
		[ -n "${found}" ] || note "kernel module ${m}.ko is missing"
	done
	sd="${moddir}modules.softdep"
	if [ -r "${sd}" ]; then
		grep -q '^softdep rtl8733bu_power post: 8733bu$' "${sd}" ||
			note "modules.softdep does not order 8733bu after rtl8733bu_power"
	else
		note "${sd} is missing"
	fi
fi

if [ -e "${TARGET_DIR}/usr/bin/nextui.elf" ]; then
	for b in usr/bin/minui.elf usr/bin/minarch.elf usr/lib/libmsettings.so \
		usr/sbin/nextui-session usr/share/nextui/res/assets@2x.png \
		usr/share/nextui/res/font1.ttf; do
		[ -e "${TARGET_DIR}/${b}" ] || note "${b} is missing"
	done
fi

for f in lib/firmware/rtl_bt/rtl8723fu_fw.bin \
	 lib/firmware/rtl_bt/rtl8723fu_config.bin \
	 lib/firmware/regulatory.db; do
	[ -s "${TARGET_DIR}/${f}" ] || note "${f} is missing or empty"
done

for f in etc/init.d/S00vardirs; do
	if [ -e "${TARGET_DIR}/${f}" ]; then
		info "removing retired /${f}"
		rm -f "${TARGET_DIR}/${f}"
	fi
done

shopt -s nullglob
for f in "${TARGET_DIR}"/lib/modules/*/updates/rocknix-joypad.ko; do
	info "removing leftover ${f#"${TARGET_DIR}"/}"
	rm -f "${f}"
done
shopt -u nullglob

rm -rf "${TARGET_DIR}/var/lib/bluetooth"
ln -sfn /run/bluetooth "${TARGET_DIR}/var/lib/bluetooth"

# Library-card mountpoints must exist on the squashfs; mkdir at runtime
# cannot create them on a read-only /mnt.
mkdir -p "${TARGET_DIR}/mnt/sd2" "${TARGET_DIR}/mnt/media"
ln -sfn /storage "${TARGET_DIR}/mnt/SDCARD"

chmod 0755 \
	"${TARGET_DIR}/usr/sbin/zlyme-led" \
	"${TARGET_DIR}/usr/sbin/zlyme-storage" \
	"${TARGET_DIR}/usr/sbin/zlyme-halt" \
	"${TARGET_DIR}/usr/sbin/zlyme-joypad-cal" \
	"${TARGET_DIR}/etc/init.d/S26joypadcal" \
	"${TARGET_DIR}/etc/init.d/S27led" \
	"${TARGET_DIR}/etc/init.d/S90minui"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-ctl" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-ctl"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-update" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-update"
[ -e "${TARGET_DIR}/etc/init.d/S18zlymeupdate" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S18zlymeupdate"
[ -e "${TARGET_DIR}/etc/init.d/S15gpudriver" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S15gpudriver"
rm -f "${TARGET_DIR}/etc/init.d/S12gpudriver"
ln -sfn zlyme-led "${TARGET_DIR}/usr/sbin/ledcontrol"

if [ -e "${TARGET_DIR}/usr/bin/portmaster" ]; then
	ssl=$(echo "${TARGET_DIR}"/usr/lib/python3.*/lib-dynload/_ssl*.so)
	sql=$(echo "${TARGET_DIR}"/usr/lib/python3.*/lib-dynload/_sqlite3*.so)
	sysc=$(echo "${TARGET_DIR}"/usr/lib/python3.*/_sysconfigdata__linux_aarch64-linux-gnu.py)
	[ -f "$ssl" ] || note "python _ssl is missing (rebuild python3 after PYTHON3_SSL=y)"
	[ -f "$sql" ] || note "python _sqlite3 is missing (rebuild python3 after PYTHON3_SQLITE=y)"
	[ -f "$sysc" ] || note "python sysconfigdata .py is missing (host pyc was unreadable)"
	[ -s "${TARGET_DIR}/etc/ssl/certs/ca-certificates.crt" ] || \
		note "ca-certificates.crt is missing (PortMaster HTTPS)"
fi

for l in var/cache var/log var/spool var/tmp var/run var/lock var/lib/dbus \
	 var/lib/bluetooth; do
	[ -L "${TARGET_DIR}/${l}" ] || note "/${l} is not a symlink"
done
if grep -qE '^[^#]*[[:space:]]/var[[:space:]]' "${TARGET_DIR}/etc/fstab"; then
	note "/etc/fstab mounts /var"
fi

# linux-reconfigure can rebuild vmlinux without rebuilding BR2 kernel-module
# packages. sizeof(struct module) then disagrees and every OOT .ko fails
# insmod (no joypad, no WiFi). Compare .gnu.linkonce.this_module to panfrost.
this_module_size() {
	readelf -W -S "$1" 2>/dev/null | awk '/gnu.linkonce.this_module/ { print $6; exit }'
}
ref_ko=""
shopt -s nullglob
for f in "${TARGET_DIR}"/lib/modules/*/kernel/drivers/gpu/drm/panfrost/panfrost.ko; do
	[ -f "$f" ] && ref_ko=$f && break
done
shopt -u nullglob
if [ -n "$ref_ko" ] && command -v readelf >/dev/null 2>&1; then
	ref_sz=$(this_module_size "$ref_ko")
	if [ -n "$ref_sz" ]; then
		shopt -s nullglob
		for ko in "${TARGET_DIR}"/lib/modules/*/updates/*.ko; do
			[ -f "$ko" ] || continue
			sz=$(this_module_size "$ko")
			if [ -z "$sz" ] || [ "$sz" != "$ref_sz" ]; then
				note "module ABI mismatch: ${ko#"${TARGET_DIR}"/} this_module=${sz:-missing} panfrost=${ref_sz} (dirclean the driver package after linux-reconfigure)"
			fi
		done
		shopt -u nullglob
	fi
fi

if [ -e "${TARGET_DIR}/sbin/modprobe" ]; then
	case "$(readlink -f "${TARGET_DIR}/sbin/modprobe")" in
		*/kmod) ;;
		*/busybox) note "modprobe is busybox, which ignores blacklist and softdep" ;;
		*) note "modprobe resolves to something unexpected" ;;
	esac
else
	note "no modprobe on the target"
fi

exit "${fail}"
