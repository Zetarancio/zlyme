#!/usr/bin/env bash
# Fail the build if required pieces are missing from the target.

set -euo pipefail

TARGET_DIR="${1:?post-build.sh: expected TARGET_DIR as the first argument}"

fail=0
note() { echo "post-build: $*" >&2; fail=1; }
info() { echo "post-build: $*" >&2; }

# A missing Buildroot config cannot prove a package was left out.
# Treat the symbol as selected so the product image still fails closed.
br2_selected() {
	local sym=$1
	if [ -z "${BR2_CONFIG:-}" ] || [ ! -f "${BR2_CONFIG}" ]; then
		return 0
	fi
	grep -qx "${sym}=y" "${BR2_CONFIG}"
}

chmod_if() {
	local f
	for f in "$@"; do
		if [ -e "$f" ]; then
			chmod 0755 "$f"
		fi
	done
}

shopt -s nullglob
moddirs=("${TARGET_DIR}"/lib/modules/*/)
shopt -u nullglob

if [ ${#moddirs[@]} -ne 1 ]; then
	note "expected exactly one /lib/modules/<release>, found ${#moddirs[@]}"
else
	moddir="${moddirs[0]}"
	if br2_selected BR2_PACKAGE_RTL8733BU; then
		found=$(find "${moddir}" -name '8733bu.ko' -print -quit)
		[ -n "${found}" ] || note "kernel module 8733bu.ko is missing"
	fi
	if br2_selected BR2_PACKAGE_RTL8733BU_POWER; then
		found=$(find "${moddir}" -name 'rtl8733bu_power.ko' -print -quit)
		[ -n "${found}" ] || note "kernel module rtl8733bu_power.ko is missing"
		sd="${moddir}modules.softdep"
		if [ -r "${sd}" ]; then
			grep -q '^softdep rtl8733bu_power post: 8733bu$' "${sd}" ||
				note "modules.softdep does not order 8733bu after rtl8733bu_power"
		else
			note "${sd} is missing"
		fi
	fi
	if br2_selected BR2_PACKAGE_MIYOO_FLIP_GAMEPAD; then
		found=$(find "${moddir}" -name 'miyoo-flip-gamepad.ko' -print -quit)
		[ -n "${found}" ] || note "kernel module miyoo-flip-gamepad.ko is missing"
	fi
fi

if [ -e "${TARGET_DIR}/usr/bin/nextui.elf" ]; then
	for b in usr/bin/minui.elf usr/lib/libmsettings.so \
		usr/sbin/nextui-session usr/share/nextui/res/assets@2x.png \
		usr/share/nextui/res/font1.ttf; do
		[ -e "${TARGET_DIR}/${b}" ] || note "${b} is missing"
	done
fi

if br2_selected BR2_PACKAGE_RTL8723FU_FIRMWARE; then
	for f in lib/firmware/rtl_bt/rtl8723fu_fw.bin \
		 lib/firmware/rtl_bt/rtl8723fu_config.bin; do
		[ -s "${TARGET_DIR}/${f}" ] || note "${f} is missing or empty"
	done
fi
if br2_selected BR2_PACKAGE_WIRELESS_REGDB; then
	[ -s "${TARGET_DIR}/lib/firmware/regulatory.db" ] || \
		note "lib/firmware/regulatory.db is missing or empty"
fi

for f in etc/init.d/S00vardirs; do
	if [ -e "${TARGET_DIR}/${f}" ]; then
		info "removing retired /${f}"
		rm -f "${TARGET_DIR}/${f}"
	fi
done

shopt -s nullglob
for f in "${TARGET_DIR}"/lib/modules/*/updates/rocknix-joypad.ko \
	"${TARGET_DIR}"/lib/modules/*/updates/rocknix-singleadc-joypad.ko; do
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
# Overlay still ships the old OS-Roms symlink. mkdir -p cannot replace it.
if [ -L "${TARGET_DIR}/roms/ports" ] || [ -f "${TARGET_DIR}/roms/ports" ]; then
	rm -f "${TARGET_DIR}/roms/ports"
fi
mkdir -p "${TARGET_DIR}/roms/ports" "${TARGET_DIR}/opt/system/Tools"
# Real dir so PORTS.pak can bind the active library here. A symlink to
# OS Roms made mount --bind overlay the OS card and duplicate the list.
ln -sfn /usr/share/portmaster/PortMaster "${TARGET_DIR}/opt/system/Tools/PortMaster"

chmod_if \
	"${TARGET_DIR}/usr/sbin/zlyme-led" \
	"${TARGET_DIR}/usr/sbin/zlyme-storage" \
	"${TARGET_DIR}/usr/sbin/zlyme-storage-udev" \
	"${TARGET_DIR}/usr/sbin/zlyme-halt" \
	"${TARGET_DIR}/usr/sbin/zlyme-gamepad-cal" \
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
if br2_selected BR2_PACKAGE_OPENSSH; then
	[ -e "${TARGET_DIR}/usr/sbin/sshd" ] || [ -e "${TARGET_DIR}/usr/bin/sshd" ] || \
		note "sshd is missing (BR2_PACKAGE_OPENSSH)"
	[ -e "${TARGET_DIR}/usr/bin/scp" ] || note "scp is missing (OpenSSH client)"
fi
[ -e "${TARGET_DIR}/usr/sbin/zlyme-ctl" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-ctl"
[ -e "${TARGET_DIR}/usr/sbin/zlyme-audio" ] && chmod 0755 "${TARGET_DIR}/usr/sbin/zlyme-audio"
if br2_selected BR2_PACKAGE_ZLYME_JACKD; then
	[ -e "${TARGET_DIR}/usr/sbin/zlyme-jackd" ] || note "zlyme-jackd is missing"
fi
if br2_selected BR2_PACKAGE_ZLYME_KEYLIDMON; then
	[ -e "${TARGET_DIR}/usr/sbin/zlyme-keylidmon" ] || note "zlyme-keylidmon is missing"
fi
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
# DTB model "Miyoo Flip" is not in its table. HW_DEVICE comes from
# /usr/share/zlyme/device.conf. platform.py aliases zlyme to the ROCKNIX
# first_run path.
# Keep PRETTY_NAME so About → OS stays the Buildroot string.
pm_short_version() {
	local root="" zver="" verfile=""
	root="${BR2_EXTERNAL_ZLYME_PATH:-}"
	if [ -z "$root" ]; then
		root=$(cd "$(dirname "$0")/../.." && pwd)
	fi
	verfile="${root}/ZLYME_VERSION"
	if [ ! -f "$verfile" ]; then
		echo "post-build: ${verfile} is missing" >&2
		return 1
	fi
	zver=$(tr -d ' \t\r\n' < "$verfile")
	if [ -z "$zver" ]; then
		echo "post-build: ZLYME_VERSION is empty" >&2
		return 1
	fi
	# The NextUI package install date is not the OS image date.
	# This string uses the date from this build.sh invocation.
	# shellcheck disable=SC1091
	. "$(cd "$(dirname "$0")" && pwd)/image-date.sh"
	zlyme_require_image_date || return 1
	zver="$zver (${ZLYME_IMAGE_DATE})"
	printf '%s\n' "$zver"
}
pm_os_release() {
	src="${TARGET_DIR}/usr/lib/os-release"
	[ -f "$src" ] || src="${TARGET_DIR}/etc/os-release"
	[ -f "$src" ] || return 0
	zver=$(pm_short_version) || return 1
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
	# shellcheck disable=SC1091
	. "${TARGET_DIR}/usr/share/zlyme/device.conf"
	: "${ZLYME_PORTMASTER_HW_DEVICE:?}"
	: "${ZLYME_NEXTUI_PLATFORM:?}"
	if [ -n "${BR2_CONFIG:-}" ] && [ -f "${BR2_CONFIG}" ]; then
		want="BR2_PACKAGE_NEXTUI_PLATFORM=\"${ZLYME_NEXTUI_PLATFORM}\""
		grep -qx "${want}" "${BR2_CONFIG}" || {
			echo "post-build: device.conf platform is not ${want}" >&2
			exit 1
		}
	fi
	if grep -q '^HW_DEVICE=' "$src"; then
		sed -i "s/^HW_DEVICE=.*/HW_DEVICE=\"${ZLYME_PORTMASTER_HW_DEVICE}\"/" "$src"
	else
		printf '%s\n' "HW_DEVICE=\"${ZLYME_PORTMASTER_HW_DEVICE}\"" >> "$src"
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

if br2_selected BR2_PACKAGE_KMOD; then
	if [ -e "${TARGET_DIR}/sbin/modprobe" ]; then
		case "$(readlink -f "${TARGET_DIR}/sbin/modprobe")" in
			*/kmod) ;;
			*/busybox) note "modprobe is busybox, which ignores blacklist and softdep" ;;
			*) note "modprobe resolves to something unexpected" ;;
		esac
	else
		note "no modprobe on the target"
	fi
fi

# The overlay blacklists panfrost so the product Mali stack can bind.
# A bring-up config that builds Mesa panfrost and does not select that
# stack keeps the driver.
if ! br2_selected BR2_PACKAGE_GPUDRIVER && ! br2_selected BR2_PACKAGE_LIBMALI; then
	if [ -f "${TARGET_DIR}/etc/modprobe.d/zlyme-gpu.conf" ]; then
		info "removing panfrost blacklist; this config has no Mali stack"
		rm -f "${TARGET_DIR}/etc/modprobe.d/zlyme-gpu.conf"
	fi
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

# glibc reads /etc/localtime. The squashfs cannot be updated at runtime,
# so this is a symlink to the zone file on /storage. S15 seeds UTC.
ln -sfn /storage/.config/nextui/shared/localtime "${TARGET_DIR}/etc/localtime"
rm -f "${TARGET_DIR}/etc/timezone"

# cheat-downloader was removed. Buildroot has no uninstall step, so an
# incremental tree would keep the old binary and its license file.
rm -rf "${TARGET_DIR}/usr/lib/zlyme/scrapegoat"
rm -rf "${TARGET_DIR}/usr/lib/zlyme/cheat-downloader"
rm -rf "${TARGET_DIR}/usr/share/licenses/cheat-downloader"
# minui-list used to install into Artwork Scraper after NextUI copied
# the pak tree. These exact stock paths must not survive that order.
rm -rf "${TARGET_DIR}/usr/share/nextui/paks/Tools/Artwork Scraper.pak"
rm -rf "${TARGET_DIR}/usr/share/nextui/paks/Tools/Cheat Downloader.pak"
rm -rf "${TARGET_DIR}/usr/share/nextui/paks/Tools/Weston.pak"
rm -rf "${TARGET_DIR}/usr/share/nextui/paks/Tools/ScrapeGoat.pak"

# nextui.mk hashes the PAK tree when calibrate.elf is installed.
# Target finalize strips that ELF afterward, so recompute the stamp
# from the binaries that actually ship.
if br2_selected BR2_PACKAGE_NEXTUI; then
	paks_ver="$(cd "$(dirname "$0")/../../package/system/nextui" && pwd)/paks-version.sh"
	sh "$paks_ver" \
		"${TARGET_DIR}/usr/share/nextui/paks" \
		"${TARGET_DIR}/usr/share/nextui/paks-version.txt"
fi

exit "${fail}"
