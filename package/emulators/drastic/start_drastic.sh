#!/bin/sh
# Config stays on the OS card. Backup / savestate slots follow $library.
# Do not export LD_PRELOAD for mkdir/cp: libdrastouch needs SDL and
# breaks BusyBox if it is loaded for the setup commands.
#
# The scratch directory on a device is the literal path /tmp/drastic-run.
# An override is a host-test seam. It is accepted only as a lexical
# /tmp path with no traversal, and only after each existing component
# is a real directory. Mounts are released by the mountinfo id this
# launch observed, not by a count of one.
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
DRASTIC_HAVE_LOCK=0
DRASTIC_KEEP_LOCK=0
DRASTIC_BACKUP_ID=
DRASTIC_STATE_ID=

if [ -n "${ZLYME_DRASTIC_WORKDIR+x}" ]; then
	drastic_override=1
	WORKDIR=$ZLYME_DRASTIC_WORKDIR
else
	drastic_override=0
	WORKDIR=/tmp/drastic-run
fi
LOCK=${WORKDIR}.lock

drastic_abandon_lock() {
	[ "$DRASTIC_HAVE_LOCK" = 1 ] || return 0
	[ "$DRASTIC_KEEP_LOCK" = 1 ] && return 0
	if rmdir "$LOCK"; then
		DRASTIC_HAVE_LOCK=0
	else
		echo "drastic: launch lock remained" >&2
	fi
}

drastic_fail() {
	echo "drastic: $*" >&2
	drastic_abandon_lock
	exit 1
}

if [ -n "${ZLYME_DRASTIC_MOUNTINFO+x}" ]; then
	if [ "$drastic_override" != 1 ] || [ -z "$ZLYME_DRASTIC_MOUNTINFO" ]; then
		drastic_fail "mount table override needs a private work directory"
	fi
	DRASTIC_MOUNTINFO=$ZLYME_DRASTIC_MOUNTINFO
else
	DRASTIC_MOUNTINFO=/proc/self/mountinfo
fi

if [ -n "${ZLYME_DRASTIC_BIN+x}" ]; then
	if [ "$drastic_override" != 1 ] || [ -z "$ZLYME_DRASTIC_BIN" ]; then
		drastic_fail "binary override needs a private work directory"
	fi
fi

# String check only. A path that fails here is not examined on disk.
drastic_lexical_ok() {
	if [ "$drastic_override" = 0 ]; then
		[ "$WORKDIR" = /tmp/drastic-run ]
		return
	fi
	case "$WORKDIR" in
		/tmp/drastic-run|/tmp/drastic-run/*) return 1 ;;
		/tmp/*) ;;
		*) return 1 ;;
	esac
	case "$WORKDIR" in
		*/|*//*|*[[:space:]]*) return 1 ;;
	esac
	case "$WORKDIR" in
		*[!/A-Za-z0-9._-]*) return 1 ;;
	esac
	_rest=${WORKDIR#/}
	while [ -n "$_rest" ]; do
		_comp=${_rest%%/*}
		case "$_comp" in
			""|.|..) return 1 ;;
		esac
		case "$_rest" in
			*/*) _rest=${_rest#*/} ;;
			*) _rest= ;;
		esac
	done
	case "$SAVES" in
		""|"$WORKDIR"|"$WORKDIR"/*) return 1 ;;
	esac
	case "$WORKDIR" in
		"$SAVES"|"$SAVES"/*) return 1 ;;
	esac
	case "$CFGDIR" in
		""|"$WORKDIR"|"$WORKDIR"/*) return 1 ;;
	esac
	case "$WORKDIR" in
		"$CFGDIR"|"$CFGDIR"/*) return 1 ;;
	esac
	return 0
}

drastic_lexical_ok || drastic_fail "work directory is not usable"

# Existing components must be real directories. A missing test directory
# is refused. The device scratch directory may be absent.
drastic_walk() {
	_prefix=
	_rest=${WORKDIR#/}
	while [ -n "$_rest" ]; do
		_comp=${_rest%%/*}
		case "$_rest" in
			*/*) _rest=${_rest#*/} ;;
			*) _rest= ;;
		esac
		_prefix=${_prefix}/${_comp}
		if [ -L "$_prefix" ]; then
			drastic_fail "work directory path contains a symlink"
		fi
		if [ -n "$_rest" ]; then
			if [ ! -d "$_prefix" ]; then
				drastic_fail "work directory path is not a directory"
			fi
		elif [ -e "$_prefix" ]; then
			if [ ! -d "$_prefix" ]; then
				drastic_fail "work directory is not a directory"
			fi
		elif [ "$drastic_override" = 1 ]; then
			drastic_fail "test work directory must already exist"
		fi
	done
}

drastic_walk

# Field 5 is the mountpoint. Optional fields sit before " - " and do
# not move field 1 or field 5. The kernel octal-escapes spaces.
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
	if (mode == "ids" && mp == want)
		print $1
	if (mode == "under" && under(mp, want))
		hit = 1
}
END {
	if (bad)
		exit 2
	if (mode == "under" && hit)
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

drastic_mounts_under() {
	drastic_table || return 2
	awk -v mode=under -v want="$1" "$drastic_awk" "$DRASTIC_MOUNTINFO"
}

drastic_list_ids() {
	drastic_table || return 2
	awk -v mode=ids -v want="$1" "$drastic_awk" "$DRASTIC_MOUNTINFO"
}

# Sets DRASTIC_ID_N and DRASTIC_ID_ONE. 2 when the table cannot be read.
drastic_scan_ids() {
	DRASTIC_ID_N=0
	DRASTIC_ID_ONE=
	_list=$(drastic_list_ids "$1") || return 2
	[ -n "$_list" ] || return 0
	while IFS= read -r _one || [ -n "$_one" ]; do
		case "$_one" in
			""|*[!0-9]*) return 2 ;;
		esac
		DRASTIC_ID_N=$((DRASTIC_ID_N + 1))
		DRASTIC_ID_ONE=$_one
	done << EOF
$_list
EOF
	return 0
}

drastic_require_clear() {
	drastic_mounts_under "$WORKDIR"
	case $? in
		0) return 0 ;;
		1) drastic_fail "work directory is mounted; not removing it" ;;
		*) drastic_fail "cannot read the mount table; not starting" ;;
	esac
}

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
		drastic_fail "work directory path contains a symlink"
	fi
	if [ -e "$WORKDIR" ] && [ ! -d "$WORKDIR" ]; then
		drastic_fail "work directory is not a directory"
	fi
	if [ -d "$WORKDIR" ]; then
		drastic_unlink_only "$WORKDIR/backup"
		drastic_unlink_only "$WORKDIR/savestates"
		if [ -L "$WORKDIR/backup" ] || [ -L "$WORKDIR/savestates" ]; then
			drastic_fail "work directory still has a save symlink"
		fi
		drastic_require_clear
		rm -rf -- "$WORKDIR" || drastic_fail "cannot remove the work directory"
		if [ -e "$WORKDIR" ] || [ -L "$WORKDIR" ]; then
			drastic_fail "work directory remained"
		fi
	fi
}

drastic_take_lock() {
	if [ -L "$LOCK" ] || [ -e "$LOCK" ]; then
		drastic_fail "work directory is already in use"
	fi
	if ! mkdir "$LOCK"; then
		drastic_fail "work directory is already in use"
	fi
	DRASTIC_HAVE_LOCK=1
}

# Return 0 and set DRASTIC_BIND_ID when this launch added one mount id.
drastic_bind() {
	_src=$1
	_dst=$2
	_label=$3
	if ! drastic_scan_ids "$_dst"; then
		echo "drastic: cannot read the mount table before binding $_label" >&2
		return 1
	fi
	if [ "$DRASTIC_ID_N" -ne 0 ]; then
		echo "drastic: $_label is already mounted; not starting" >&2
		return 1
	fi
	if ! mount --bind "$_src" "$_dst"; then
		echo "drastic: bind failed for $_label; not starting" >&2
		return 1
	fi
	if ! drastic_scan_ids "$_dst"; then
		DRASTIC_KEEP_LOCK=1
		echo "drastic: cannot read the mount table after binding $_label" >&2
		return 1
	fi
	if [ "$DRASTIC_ID_N" -ne 1 ]; then
		DRASTIC_KEEP_LOCK=1
		echo "drastic: $_label bind is not a single mount; not starting" >&2
		return 1
	fi
	DRASTIC_BIND_ID=$DRASTIC_ID_ONE
	return 0
}

# Unmount only when the only id at the path is the one this launch stored.
drastic_release() {
	_dst=$1
	_label=$2
	_want=$3
	case "$_want" in
		""|*[!0-9]*)
			echo "drastic: $_label has no recorded mount; not unmounting" >&2
			return 1
			;;
	esac
	if ! drastic_scan_ids "$_dst"; then
		echo "drastic: cannot read the mount table while releasing $_label" >&2
		return 1
	fi
	if [ "$DRASTIC_ID_N" -ne 1 ] || [ "$DRASTIC_ID_ONE" != "$_want" ]; then
		echo "drastic: $_label mount is not the one this launch created; not unmounting" >&2
		return 1
	fi
	if ! umount "$_dst"; then
		echo "drastic: unmount failed for $_label" >&2
		return 1
	fi
	return 0
}

drastic_take_lock

BIN=
if [ -n "${ZLYME_DRASTIC_BIN+x}" ]; then
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
mkdir -p "$CFGDIR" "$SAVES/backup" "$SAVES/savestates" \
	"$WORKDIR/backup" "$WORKDIR/savestates"

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

cp -f "$BIN" "$WORKDIR/drastic" || drastic_fail "cannot copy the binary"
chmod 0755 "$WORKDIR/drastic" || drastic_fail "cannot mark the binary executable"

# Release mounts this launch recorded. A failure leaves the lock so the
# next start cannot remove the scratch directory.
drastic_fail_bound() {
	if [ -n "$DRASTIC_BACKUP_ID" ]; then
		drastic_release "$WORKDIR/backup" backup "$DRASTIC_BACKUP_ID" || DRASTIC_KEEP_LOCK=1
	fi
	if [ -n "$DRASTIC_STATE_ID" ]; then
		drastic_release "$WORKDIR/savestates" savestates "$DRASTIC_STATE_ID" || DRASTIC_KEEP_LOCK=1
	fi
	drastic_fail "$1"
}

if ! drastic_bind "$SAVES/backup" "$WORKDIR/backup" backup; then
	drastic_fail "backup bind failed"
fi
DRASTIC_BACKUP_ID=$DRASTIC_BIND_ID
if ! drastic_bind "$SAVES/savestates" "$WORKDIR/savestates" savestates; then
	drastic_fail_bound "savestates bind failed"
fi
DRASTIC_STATE_ID=$DRASTIC_BIND_ID

cd "$WORKDIR" || drastic_fail_bound "cannot enter the work directory"
if [ -n "${ZLYME_DRASTIC_BIN+x}" ] && [ -z "${ZLYME_DRASTIC_PRELOAD:-}" ]; then
	./drastic "$@"
else
	LD_PRELOAD="${ZLYME_DRASTIC_PRELOAD:-/usr/lib/libdrastouch.so}" ./drastic "$@"
fi
st=$?
cp -f "$WORKDIR/drastic.cfg" "$CFGDIR/drastic.cfg" 2>/dev/null || true
rel=0
drastic_release "$WORKDIR/backup" backup "$DRASTIC_BACKUP_ID" || rel=1
drastic_release "$WORKDIR/savestates" savestates "$DRASTIC_STATE_ID" || rel=1
if [ "$rel" -ne 0 ]; then
	DRASTIC_KEEP_LOCK=1
	echo "drastic: save mounts were not released" >&2
	if [ "$st" -eq 0 ]; then
		st=1
	fi
else
	drastic_abandon_lock
fi
exit "$st"
