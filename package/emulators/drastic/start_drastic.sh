#!/bin/sh
# Config stays on the OS card. Backup / savestate slots follow $library.
# Do not export LD_PRELOAD for mkdir/cp: libdrastouch needs SDL and
# breaks BusyBox if it is loaded for the setup commands.
#
# /tmp/drastic-run is cleared only when the mount table proves that
# neither it nor anything under it is a mount. A bind left by MENU+START
# or SIGKILL is still a directory to rm, and rm would delete the save
# files through it. A failed bind is not replaced with a symlink: GNU rm
# follows a symlink when the path has a trailing slash, and this script
# does not depend on the other form. Device numbers are not a substitute
# for the mount table. The rootfs BusyBox rm has no one-file-system flag.
export SDL_TOUCH_MOUSE_EVENTS="${SDL_TOUCH_MOUSE_EVENTS:-0}"
if [ -r /usr/share/zlyme/pak-input.sh ]; then
	# shellcheck disable=SC1091
	. /usr/share/zlyme/pak-input.sh
fi

SDCARD="${SDCARD_PATH:-/storage}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SDCARD/.config}"
CFGDIR="$XDG_CONFIG_HOME/drastic"
SAVES="${SAVES_PATH:-$SDCARD/Saves}/NDS"
SEED=/usr/share/drastic/config/drastic.cfg
WORKDIR=${ZLYME_DRASTIC_WORKDIR:-/tmp/drastic-run}

drastic_fail() {
	echo "drastic: $*" >&2
	exit 1
}

# A private mount table is a host-test seam. Without a private work
# directory it would hide a real mount at the device path.
if [ -n "${ZLYME_DRASTIC_MOUNTINFO:-}" ]; then
	if [ -z "${ZLYME_DRASTIC_WORKDIR:-}" ]; then
		drastic_fail "mount table override needs a private work directory"
	fi
	DRASTIC_MOUNTINFO=$ZLYME_DRASTIC_MOUNTINFO
else
	DRASTIC_MOUNTINFO=/proc/self/mountinfo
fi

if [ -n "${ZLYME_DRASTIC_BIN:-}" ] && [ -z "${ZLYME_DRASTIC_WORKDIR:-}" ]; then
	drastic_fail "binary override needs a private work directory"
fi

drastic_reject_workdir() {
	case "$WORKDIR" in
		""|/|.|..|/tmp|/run|/var|/storage|/mnt|/mnt/sd2|/mnt/media|/boot|/usr|/etc|/dev|/proc|/sys)
			drastic_fail "work directory is not usable"
			;;
	esac
	case "$WORKDIR" in
		/*) ;;
		*) drastic_fail "work directory is not absolute" ;;
	esac
	case "$WORKDIR" in
		*[[:space:]]*)
			drastic_fail "work directory is not usable"
			;;
	esac
	case "$SAVES" in
		""|"$WORKDIR"|"$WORKDIR"/*)
			drastic_fail "work directory contains the save directory"
			;;
	esac
	case "$WORKDIR" in
		"$SAVES"|"$SAVES"/*)
			drastic_fail "work directory is inside the save directory"
			;;
	esac
	case "$CFGDIR" in
		""|"$WORKDIR"|"$WORKDIR"/*)
			drastic_fail "work directory contains the config directory"
			;;
	esac
	case "$WORKDIR" in
		"$CFGDIR"|"$CFGDIR"/*)
			drastic_fail "work directory is inside the config directory"
			;;
	esac
}

# Field 5 is the mountpoint. Optional fields sit before " - " and do
# not move it. The kernel octal-escapes spaces, so field 5 has none.
# shellcheck disable=SC2016 # The program is awk, not shell.
drastic_awk='
function decode(s,    out, i, n, chunk, a, b, c, oct) {
	out = ""
	n = length(s)
	i = 1
	while (i <= n) {
		if (substr(s, i, 1) == "\\" && i + 3 <= n) {
			chunk = substr(s, i + 1, 3)
			if (chunk ~ /^[0-7][0-7][0-7]$/) {
				a = index("01234567", substr(chunk, 1, 1)) - 1
				b = index("01234567", substr(chunk, 2, 1)) - 1
				c = index("01234567", substr(chunk, 3, 1)) - 1
				oct = a * 64 + b * 8 + c
				out = out sprintf("%c", oct)
				i += 4
				continue
			}
		}
		out = out substr(s, i, 1)
		i++
	}
	return out
}
function under(mp, root) {
	if (mp == root)
		return 1
	if (length(mp) > length(root) &&
		substr(mp, 1, length(root) + 1) == root "/")
		return 1
	return 0
}
NF == 0 { next }
NF < 5 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ { bad = 1; next }
{
	mp = decode($5)
	if (mode == "under" && under(mp, want))
		hit = 1
	if (mode == "count" && mp == want)
		n++
}
END {
	if (bad)
		exit 2
	if (mode == "count") {
		print n + 0
		exit 0
	}
	if (hit)
		exit 1
	exit 0
}
'

drastic_table() {
	if [ -f "$DRASTIC_MOUNTINFO" ] && [ -r "$DRASTIC_MOUNTINFO" ]; then
		return 0
	fi
	return 2
}

# 0 clear, 1 a mount is at or under the work directory, 2 unreadable.
drastic_mounts_under() {
	drastic_table || return 2
	awk -v mode=under -v want="$1" "$drastic_awk" "$DRASTIC_MOUNTINFO"
}

drastic_mount_count() {
	drastic_table || return 2
	awk -v mode=count -v want="$1" "$drastic_awk" "$DRASTIC_MOUNTINFO"
}

drastic_require_clear() {
	drastic_mounts_under "$WORKDIR"
	case $? in
		0) return 0 ;;
		1) drastic_fail "work directory is mounted; not removing it" ;;
		*) drastic_fail "cannot read the mount table; not starting" ;;
	esac
}

# Remove a symlink and not the directory it names.
drastic_unlink_only() {
	if [ -L "$1" ]; then
		rm -- "$1" || drastic_fail "cannot remove symlink $1"
	fi
	if [ -L "$1" ]; then
		drastic_fail "symlink $1 remained"
	fi
}

drastic_clear_workdir() {
	drastic_require_clear
	if [ -L "$WORKDIR" ]; then
		drastic_unlink_only "$WORKDIR"
		drastic_require_clear
		return 0
	fi
	if [ -e "$WORKDIR" ] && [ ! -d "$WORKDIR" ]; then
		drastic_fail "work directory is not a directory"
	fi
	if [ -d "$WORKDIR" ]; then
		drastic_unlink_only "$WORKDIR/backup"
		drastic_unlink_only "$WORKDIR/savestates"
		if [ -L "$WORKDIR" ] || [ -L "$WORKDIR/backup" ] || [ -L "$WORKDIR/savestates" ]; then
			drastic_fail "work directory still has a save symlink"
		fi
		drastic_require_clear
		rm -rf -- "$WORKDIR" || drastic_fail "cannot remove the work directory"
		if [ -e "$WORKDIR" ] || [ -L "$WORKDIR" ]; then
			drastic_fail "work directory remained"
		fi
	fi
}

drastic_bind() {
	_src=$1
	_dst=$2
	_label=$3
	_before=$(drastic_mount_count "$_dst")
	_st=$?
	if [ "$_st" -ne 0 ]; then
		drastic_fail "cannot read the mount table before binding $_label"
	fi
	if [ "$_before" -ne 0 ]; then
		drastic_fail "$_label is already mounted; not starting"
	fi
	if ! mount --bind "$_src" "$_dst"; then
		echo "drastic: bind failed for $_label; not starting" >&2
		exit 1
	fi
	_after=$(drastic_mount_count "$_dst")
	_st=$?
	if [ "$_st" -ne 0 ]; then
		drastic_fail "cannot read the mount table after binding $_label"
	fi
	if [ "$_after" -ne 1 ]; then
		drastic_fail "$_label bind is not a single mount; not starting"
	fi
}

# Unmount only a single visible mount at the path this launch bound.
# Any other count is left mounted.
drastic_release() {
	_dst=$1
	_label=$2
	_n=$(drastic_mount_count "$_dst")
	_st=$?
	if [ "$_st" -ne 0 ]; then
		echo "drastic: cannot read the mount table while releasing $_label" >&2
		return 1
	fi
	if [ "$_n" -eq 0 ]; then
		echo "drastic: $_label was not mounted at exit" >&2
		return 1
	fi
	if [ "$_n" -ne 1 ]; then
		echo "drastic: $_label has $_n mounts; not unmounting" >&2
		return 1
	fi
	if ! umount "$_dst"; then
		echo "drastic: unmount failed for $_label" >&2
		return 1
	fi
	return 0
}

drastic_reject_workdir

mkdir -p "$CFGDIR" "$SAVES/backup" "$SAVES/savestates"

BIN=
if [ -n "${ZLYME_DRASTIC_BIN:-}" ]; then
	BIN=$ZLYME_DRASTIC_BIN
elif [ -x /usr/bin/drastic ]; then
	BIN=/usr/bin/drastic
elif [ -x /usr/share/drastic/drastic ]; then
	BIN=/usr/share/drastic/drastic
fi
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
	drastic_fail "binary missing"
fi

drastic_clear_workdir
mkdir -p "$WORKDIR/backup" "$WORKDIR/savestates"

# An existing cfg is the user's. zlyme-stock-seed copies the stock file
# when it is missing. This launcher does not rewrite button numbers.
if [ -f "$SEED" ] && [ ! -s "$CFGDIR/drastic.cfg" ]; then
	cp "$SEED" "$CFGDIR/drastic.cfg"
fi
if [ -f "$CFGDIR/drastic.cfg" ]; then
	cp "$CFGDIR/drastic.cfg" "$WORKDIR/drastic.cfg"
elif [ -f "$SEED" ]; then
	cp "$SEED" "$WORKDIR/drastic.cfg"
fi

cp -f "$BIN" "$WORKDIR/drastic"
chmod 0755 "$WORKDIR/drastic"

drastic_bind "$SAVES/backup" "$WORKDIR/backup" backup
drastic_bind "$SAVES/savestates" "$WORKDIR/savestates" savestates

cd "$WORKDIR" || drastic_fail "cannot enter the work directory"
if [ -n "${ZLYME_DRASTIC_BIN:-}" ] && [ -z "${ZLYME_DRASTIC_PRELOAD:-}" ]; then
	./drastic "$@"
else
	LD_PRELOAD="${ZLYME_DRASTIC_PRELOAD:-/usr/lib/libdrastouch.so}" ./drastic "$@"
fi
st=$?
cp -f "$WORKDIR/drastic.cfg" "$CFGDIR/drastic.cfg" 2>/dev/null || true
rel=0
drastic_release "$WORKDIR/backup" backup || rel=1
drastic_release "$WORKDIR/savestates" savestates || rel=1
if [ "$rel" -ne 0 ]; then
	echo "drastic: save mounts were not released" >&2
	if [ "$st" -eq 0 ]; then
		st=1
	fi
fi
exit "$st"
