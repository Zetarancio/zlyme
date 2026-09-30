#!/bin/sh
# zlyme-timezone ensure must run after /storage is mounted and before
# the background seed. It must not also run inside seed().
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
S15="$ROOT/board/my355/fsoverlay/etc/init.d/S15bootpart"
awk '
	/^seed\(\)/ { in_seed = 1 }
	in_seed && /^}/ { in_seed = 0 }
	in_seed && /zlyme-timezone/ { print "timezone ensure is inside seed()" > "/dev/stderr"; bad = 1 }
	/^start\(\)/ { in_start = 1 }
	in_start && /^}/ { in_start = 0 }
	in_start && /zlyme-timezone ensure/ { seen_tz = 1 }
	in_start && seen_tz && /seed &/ { seen_bg = 1 }
	in_start && /seed &/ && !seen_tz { print "seed & is before timezone ensure" > "/dev/stderr"; bad = 1 }
	END {
		if (!seen_tz) { print "missing synchronous timezone ensure" > "/dev/stderr"; bad = 1 }
		if (!seen_bg) { print "background seed missing after timezone ensure" > "/dev/stderr"; bad = 1 }
		if (bad) exit 1
	}
' "$S15"
echo "timezone boot order ok"
