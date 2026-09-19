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
	for b in usr/bin/minui.elf usr/lib/libmsettings.so \
		usr/sbin/nextui-session usr/share/nextui/res/assets@2x.png \
		usr/share/nextui/res/font1.ttf; do
		[ -e "${TARGET_DIR}/${b}" ] || note "${b} is missing"
	done
	[ -x "${TARGET_DIR}/usr/bin/mergerfs" ] || note "mergerfs is missing"
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
# Samba private/msg.sock needs unix 0700; ZLYME is exFAT. tmpfs is enough
# for a guest share (no persisted secrets).
rm -rf "${TARGET_DIR}/var/lib/samba"
ln -sfn /tmp/samba-lib "${TARGET_DIR}/var/lib/samba"

# Library-card mountpoints must exist on the squashfs; mkdir at runtime
# cannot create them on a read-only /mnt. /boot must exist so initramfs
# can mount --move ZLYMEBOOT onto it.
mkdir -p "${TARGET_DIR}/mnt/sd2" "${TARGET_DIR}/mnt/media" "${TARGET_DIR}/boot"
ln -sfn /storage "${TARGET_DIR}/mnt/SDCARD"
# PortMaster scripts source /roms/ports/PortMaster/control.txt and set
# GAMEDIR=/$directory/ports/<name> with directory=roms. NextUI's folder
# is "Ports (PORTS)". /opt/system/Tools/PortMaster is the other lookup.
mkdir -p "${TARGET_DIR}/roms" "${TARGET_DIR}/opt/system/Tools"
ln -sfn "/storage/Roms/Ports (PORTS)" "${TARGET_DIR}/roms/ports"
ln -sfn /roms/ports/PortMaster "${TARGET_DIR}/opt/system/Tools/PortMaster"

chmod 0755 \
	"${TARGET_DIR}/usr/sbin/zlyme-led" \
	"${TARGET_DIR}/usr/sbin/zlyme-storage" \
	"${TARGET_DIR}/usr/sbin/zlyme-storage-udev" \
	"${TARGET_DIR}/usr/sbin/zlyme-halt" \
	"${TARGET_DIR}/usr/sbin/zlyme-joypad-cal" \
	"${TARGET_DIR}/etc/init.d/S26joypadcal" \
	"${TARGET_DIR}/etc/init.d/S25jackd" \
	"${TARGET_DIR}/etc/init.d/S26keylidmon" \
	"${TARGET_DIR}/etc/init.d/S27led" \
	"${TARGET_DIR}/etc/init.d/S90minui"
# BusyBox wget has no TLS. Pico-8 Splore uses wget https:// so force
# the curl wrapper even if busybox.links recreated the applet.
wget_wrap="$(cd "$(dirname "$0")" && pwd)/fsoverlay/usr/bin/wget"
if [ -f "$wget_wrap" ]; then
	cp -f "$wget_wrap" "${TARGET_DIR}/usr/bin/wget"
	chmod 0755 "${TARGET_DIR}/usr/bin/wget"
	ln -sfn /usr/bin/wget "${TARGET_DIR}/bin/wget"
else
	note "wget curl wrapper missing from fsoverlay"
fi
[ -e "${TARGET_DIR}/etc/init.d/S50sshd" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S50sshd"
[ -e "${TARGET_DIR}/usr/sbin/sshd" ] || [ -e "${TARGET_DIR}/usr/bin/sshd" ] || \
	note "sshd is missing (BR2_PACKAGE_OPENSSH)"
[ -e "${TARGET_DIR}/usr/bin/scp" ] || note "scp is missing (OpenSSH client)"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-ctl" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-ctl"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-audio" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-audio"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-jackd" ] || note "zlyme-jackd is missing"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-keylidmon" ] || note "zlyme-keylidmon is missing"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-btsink" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-btsink"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-radios" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-radios"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-combo" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-combo"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-bluetooth" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-bluetooth"
[ -e "${TARGET_DIR}/etc/init.d/S46btsink" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S46btsink"
[ -e "${TARGET_DIR}/etc/init.d/rcS" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/rcS"
[ -e "${TARGET_DIR}/etc/init.d/rc.late" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/rc.late"
[ -e "${TARGET_DIR}/etc/init.d/S30dbus-daemon" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S30dbus-daemon"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-update" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-update"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-splash-progress" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-splash-progress"
[ -e "${TARGET_DIR}/etc/init.d/S12splash" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S12splash"
[ -e "${TARGET_DIR}/etc/init.d/S18zlymeupdate" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S18zlymeupdate"
[ -e "${TARGET_DIR}/etc/init.d/S15gpudriver" ] && chmod 0755 "${TARGET_DIR}/etc/init.d/S15gpudriver"
rm -f "${TARGET_DIR}/etc/init.d/S12gpudriver" \
	"${TARGET_DIR}/usr/bin/keymon.elf" \
	"${TARGET_DIR}/usr/sbin/zlyme-volmon" \
	"${TARGET_DIR}/etc/init.d/S26keymon" \
	"${TARGET_DIR}/usr/sbin/flip-jackd" \
	"${TARGET_DIR}/usr/bin/minarch.elf" \
	"${TARGET_DIR}/usr/bin/gametimectl.elf"
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
	if [ ! -x "${TARGET_DIR}/usr/bin/bash" ] && [ ! -x "${TARGET_DIR}/bin/bash" ]; then
		note "bash is missing (PortMaster scripts are #!/bin/bash)"
	fi
fi

for l in var/cache var/log var/spool var/tmp var/run var/lock var/lib/dbus \
	 var/lib/bluetooth var/lib/samba; do
	[ -L "${TARGET_DIR}/${l}" ] || note "/${l} is not a symlink"
done
if [ -e "${TARGET_DIR}/usr/share/minui" ] && [ ! -L "${TARGET_DIR}/usr/share/minui" ]; then
	note "/usr/share/minui must stay a symlink to nextui"
fi
if grep -qE '^[^#]*[[:space:]]/var[[:space:]]' "${TARGET_DIR}/etc/fstab"; then
	note "/etc/fstab mounts /var"
fi

# PortMaster harbourmaster only parses quoted KEY="value" (NAME→CFW,
# VERSION/OS_VERSION→version, HW_DEVICE→device). Unquoted
# VERSION=2026.02.3 left the GUI at 0.0.0. Use the same short string
# Settings → version shows (zlyme39 plus build date), not git describe.
# DTB model "Miyoo Flip" is not in its table. HW_DEVICE still selects
# miyoo-flip. platform.py aliases zlyme to the ROCKNIX first_run path.
# Keep PRETTY_NAME so About → OS stays the Buildroot string.
pm_short_version() {
	local raw="" date="" zver=""
	if [ -f "${TARGET_DIR}/usr/share/nextui/version.txt" ]; then
		raw=$(tr -d '\r\n' < "${TARGET_DIR}/usr/share/nextui/version.txt")
		case "$raw" in
			*-zlyme*) zver="zlyme${raw##*-zlyme}" ;;
			*) zver=$raw ;;
		esac
	fi
	if [ -f "${TARGET_DIR}/usr/share/nextui/build-date.txt" ]; then
		date=$(tr -d '\r\n' < "${TARGET_DIR}/usr/share/nextui/build-date.txt")
	fi
	if [ -z "$zver" ]; then
		zver=${date:-unknown}
	elif [ -n "$date" ]; then
		zver="$zver ($date)"
	fi
	printf '%s\n' "$zver"
}
pm_os_release() {
	src="${TARGET_DIR}/usr/lib/os-release"
	[ -f "$src" ] || src="${TARGET_DIR}/etc/os-release"
	[ -f "$src" ] || return 0
	zver=$(pm_short_version)
	mkdir -p "${TARGET_DIR}/usr/share/zlyme"
	printf '%s\n' "$zver" > "${TARGET_DIR}/usr/share/zlyme/version"
	if grep -q '^NAME=' "$src"; then
		sed -i 's/^NAME=.*/NAME="Zlyme"/' "$src"
	else
		printf '%s\n' 'NAME="Zlyme"' >> "$src"
	fi
	if grep -q '^VERSION=' "$src"; then
		sed -i "s/^VERSION=.*/VERSION=\"${zver}\"/" "$src"
	else
		printf '%s\n' "VERSION=\"${zver}\"" >> "$src"
	fi
	if grep -q '^OS_VERSION=' "$src"; then
		sed -i "s/^OS_VERSION=.*/OS_VERSION=\"${zver}\"/" "$src"
	else
		printf '%s\n' "OS_VERSION=\"${zver}\"" >> "$src"
	fi
	if grep -q '^HW_DEVICE=' "$src"; then
		sed -i 's/^HW_DEVICE=.*/HW_DEVICE="miyoo-flip"/' "$src"
	else
		printf '%s\n' 'HW_DEVICE="miyoo-flip"' >> "$src"
	fi
	if [ -f "${TARGET_DIR}/etc/os-release" ] && [ ! -L "${TARGET_DIR}/etc/os-release" ] && \
		[ "${TARGET_DIR}/etc/os-release" != "$src" ]; then
		cp -f "$src" "${TARGET_DIR}/etc/os-release"
	fi
}
pm_os_release

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

# Fluidsynth 2.4 saw SDL3 cmake files in staging (Qt leftover) and
# DT_NEEDED libSDL3.so.0. We do not ship SDL3. A tiny SONAME stub is
# enough; MIDI still goes through ALSA.
if [ -n "${HOST_DIR:-}" ] && [ -x "${HOST_DIR}/bin/aarch64-buildroot-linux-gnu-gcc" ]; then
	stub="$(cd "$(dirname "$0")" && pwd)/sdl3-stub.c"
	map="$(cd "$(dirname "$0")" && pwd)/sdl3-stub.map"
	if [ -f "$stub" ] && [ -f "$map" ]; then
		"${HOST_DIR}/bin/aarch64-buildroot-linux-gnu-gcc" -shared -fPIC \
			-o "${TARGET_DIR}/usr/lib/libSDL3.so.0" \
			-Wl,-soname,libSDL3.so.0 -Wl,--version-script="$map" \
			"$stub"
	fi
fi

# Class B after NextUI. Keep generated getty/sysinit; only add ::once.
if [ -f "${TARGET_DIR}/etc/inittab" ]; then
	if ! grep -q '/etc/init.d/rc.late' "${TARGET_DIR}/etc/inittab"; then
		if grep -q '::sysinit:/etc/init.d/rcS' "${TARGET_DIR}/etc/inittab"; then
			sed -i '/::sysinit:\/etc\/init.d\/rcS/a ::once:\/etc\/init.d\/rc.late' \
				"${TARGET_DIR}/etc/inittab"
		else
			printf '%s\n' '::once:/etc/init.d/rc.late' >> "${TARGET_DIR}/etc/inittab"
		fi
	fi
fi

exit "${fail}"
