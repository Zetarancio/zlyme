#!/bin/sh
# PortMaster uses a Zlyme scheme inside default_theme.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
inject=$ROOT/package/system/portmaster/zlyme-theme/inject-scheme.py
select=$ROOT/package/system/portmaster/zlyme-theme/select-scheme.py
launch=$ROOT/package/system/portmaster/portmaster-launch
mk=$ROOT/package/system/portmaster/portmaster.mk

if grep -E -q 'mkdir .*themes/Zlyme|cp .*themes/Zlyme' "$launch" "$mk"; then
	echo "portmaster still installs a standalone Zlyme theme" >&2
	exit 1
fi
grep -q 'themes/Zlyme' "$mk"
grep -q 'pylibs/default_theme/theme.json' "$mk"
grep -q 'apply_zlyme_scheme' "$launch"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$work/theme.json" << 'PY'
import json, sys
src = {
  "#info": {"name": "Default Theme", "default-scheme": "Light Mode"},
  "#schemes": {
    "Darkest Mode": {
      "#pallet": {
        "background": [0, 0, 0, 255],
        "list_text": [255, 255, 255, 255],
        "list_selected": [153, 180, 255, 255],
        "list_unselectable": [200, 0, 0, 255],
        "selection-fill": [50, 80, 155],
        "button": [0, 0, 0, 255]
      },
      "#resources": {"buttons.png": {"image-mod": [255, 255, 255]}}
    }
  },
  "ports_list": {"select-fill": "selection-fill", "select-color": "list_selected"}
}
open(sys.argv[1], "w").write(json.dumps(src))
PY
python3 "$inject" "$work/theme.json"
python3 - "$work/theme.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["#info"]["name"] == "Default Theme"
assert data["#info"]["default-scheme"] == "Zlyme"
z = data["#schemes"]["Zlyme"]
d = data["#schemes"]["Darkest Mode"]
assert d["#pallet"]["list_unselectable"] == [200, 0, 0, 255]
assert d["#pallet"]["background"] == [0, 0, 0, 255]
assert z["#pallet"]["background"] == [0, 0, 0, 255]
assert z["#pallet"]["list_text"] == [255, 255, 255, 255]
assert z["#pallet"]["button"] == [0, 0, 0, 255]
assert z["#pallet"]["list_unselectable"][:3] == [250, 124, 8]
assert z["#pallet"]["list_selected"][:3] == [252, 156, 20]
assert z["#pallet"]["selection-fill"][:3] == [138, 62, 6]
assert z["#resources"] == d["#resources"]
assert data["ports_list"]["select-fill"] == "selection-fill"
PY

# Fresh config.
mkdir -p "$work/themes/Zlyme" "$work/themes/Other"
echo stale > "$work/themes/Zlyme/theme.json"
echo keep > "$work/themes/Other/theme.json"
python3 "$select" "$work/fresh/config.json" "$work/themes"
python3 - "$work/fresh/config.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["theme"] == "default_theme"
assert data["theme-scheme"] == "Zlyme"
PY
test ! -e "$work/themes/Zlyme"
test -f "$work/themes/Other/theme.json"

# Old standalone theme converts once. A later scheme is kept.
mkdir -p "$work/old"
printf '%s\n' '{"theme": "Zlyme", "theme-scheme": "Zlyme", "other": 1}' > "$work/old/config.json"
mkdir -p "$work/themes/Zlyme"
python3 "$select" "$work/old/config.json" "$work/themes"
python3 - "$work/old/config.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["theme"] == "default_theme"
assert data["theme-scheme"] == "Zlyme"
assert data["other"] == 1
PY
python3 - << PY
import json
p = "$work/old/config.json"
data = json.load(open(p))
data["theme-scheme"] = "Dracula"
json.dump(data, open(p, "w"))
PY
python3 "$select" "$work/old/config.json" "$work/themes"
python3 - "$work/old/config.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["theme"] == "default_theme"
assert data["theme-scheme"] == "Dracula"
PY

# An unrelated theme is not reset, and its scheme stays.
mkdir -p "$work/other"
printf '%s\n' '{"theme": "Handheld", "theme-scheme": "Dark Mode"}' > "$work/other/config.json"
python3 "$select" "$work/other/config.json" "$work/themes"
python3 - "$work/other/config.json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["theme"] == "Handheld"
assert data["theme-scheme"] == "Dark Mode"
PY

mkdir -p "$work/bad"
printf '%s\n' '{ this is not json' > "$work/bad/config.json"
cp "$work/bad/config.json" "$work/bad/before"
if python3 "$select" "$work/bad/config.json" "$work/themes" 2>"$work/bad/err"; then
	:
else
	echo "malformed config was treated as fatal" >&2
	exit 1
fi
cmp -s "$work/bad/before" "$work/bad/config.json"
grep -q 'not valid JSON' "$work/bad/err"

echo "portmaster theme ok"
