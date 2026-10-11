# Decode and compare /proc/mounts targets.
#
# The kernel escapes space, tab, newline, and backslash in the mount
# table (\040, \011, \012, \134). Callers compare decoded paths. A
# registry or library list stores the raw path, never the escaped field.
#
# Sourced. Callers pass the table path. Tests use a copy; production
# passes /proc/mounts.

mounts_decode() {
	python3 -c '
import sys
s = sys.argv[1]
out = []
i = 0
n = len(s)
while i < n:
    chunk = s[i + 1:i + 4]
    if (
        s[i] == "\\"
        and len(chunk) == 3
        and all(c in "01234567" for c in chunk)
    ):
        out.append(chr(int(chunk, 8)))
        i += 4
    else:
        out.append(s[i])
        i += 1
sys.stdout.write("".join(out))
' "$1"
}

mounts_targets() {
	file=$1
	python3 - "$file" <<'PY'
import sys

def decode(s):
    out = []
    i = 0
    n = len(s)
    while i < n:
        chunk = s[i + 1:i + 4]
        if (
            s[i] == "\\"
            and len(chunk) == 3
            and all(c in "01234567" for c in chunk)
        ):
            out.append(chr(int(chunk, 8)))
            i += 4
        else:
            out.append(s[i])
            i += 1
    return "".join(out)

with open(sys.argv[1], "r", encoding="utf-8", errors="surrogateescape") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line or line[0] == "#":
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        sys.stdout.write(decode(parts[1]) + "\n")
PY
}

mounts_has() {
	file=$1
	want=$2
	found=1
	body=$(mounts_targets "$file") || return 1
	while IFS= read -r target || [ -n "$target" ]; do
		[ -n "$target" ] || continue
		if [ "$target" = "$want" ]; then
			found=0
			break
		fi
	done <<END_ZLYME_MOUNTS
$body
END_ZLYME_MOUNTS
	return "$found"
}

mounts_count() {
	file=$1
	want=$2
	n=0
	body=$(mounts_targets "$file") || return 1
	while IFS= read -r target || [ -n "$target" ]; do
		[ -n "$target" ] || continue
		if [ "$target" = "$want" ]; then
			n=$((n + 1))
		fi
	done <<END_ZLYME_MOUNTS
$body
END_ZLYME_MOUNTS
	printf '%s\n' "$n"
}
