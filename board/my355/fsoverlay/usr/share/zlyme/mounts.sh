# Decode and compare /proc/mounts targets.
#
# The kernel escapes space, tab, newline, and backslash in the mount
# table (\040, \011, \012, \134). Callers compare decoded paths. A
# registry or library list stores the raw path, never the escaped field.
#
# The minimal image has BusyBox awk and does not have Python. This
# helper stays on that toolset.
#
# Sourced. Callers pass the table path. Tests use a copy; production
# passes /proc/mounts.

mounts_scan() {
	ZLYME_MOUNT_MODE=$1 \
	ZLYME_MOUNT_WANT=${3-} \
	ZLYME_MOUNT_FIELD=${4-} \
	awk '
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
function hit(src, dst) {
	if (mode == "targets") {
		printf "%s\n", dst
		return
	}
	if (mode == "has" && dst == want) found = 1
	if (mode == "count" && dst == want) count++
	if (mode == "has_source" && src == want) found = 1
	if (mode == "target_of" && src == want && found == 0) {
		printf "%s", dst
		found = 1
	}
	if (mode == "source" && dst == want && found == 0) {
		printf "%s", src
		found = 1
	}
}
BEGIN {
	mode = ENVIRON["ZLYME_MOUNT_MODE"]
	want = ENVIRON["ZLYME_MOUNT_WANT"]
	count = 0
	found = 0
	if (mode == "decode") {
		printf "%s", decode(ENVIRON["ZLYME_MOUNT_FIELD"])
		exit 0
	}
}
$0 ~ /^#/ { next }
NF < 2 { next }
{
	hit(decode($1), decode($2))
	if (found && mode != "count" && mode != "targets") exit 0
}
END {
	if (mode == "decode" || mode == "targets") exit 0
	if (mode == "count") {
		printf "%s\n", count + 0
		exit 0
	}
	exit (found + 0) ? 0 : 1
}
' "$2"
}

mounts_decode() {
	mounts_scan decode /dev/null "" "$1"
}

mounts_targets() {
	mounts_scan targets "$1"
}

mounts_has() {
	mounts_scan has "$1" "$2"
}

mounts_count() {
	mounts_scan count "$1" "$2"
}

# Status 0 when decoded field 1 is exactly $2.
mounts_has_source() {
	mounts_scan has_source "$1" "$2"
}

# Decoded target whose decoded source is exactly $2.
mounts_target_of() {
	mounts_scan target_of "$1" "$2"
}

# First source whose decoded target is exactly $2. Empty and status 1
# when that target is not in the table.
mounts_source() {
	mounts_scan source "$1" "$2"
}
