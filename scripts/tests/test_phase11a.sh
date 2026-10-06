#!/bin/sh
# Phase 11A host contract: proxy, Tools order, updater classification,
# release-note policy, and the live build log. Nothing here is installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
PROXY=$ROOT/board/my355/fsoverlay/usr/sbin/zlyme-proxy
fail() {
	echo "phase11a: $*" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ZLYME_PROXY_CONF=$work/proxy.conf

# Disabled, including a missing file, emits no proxy URL.
out=$("$PROXY" env)
printf '%s\n' "$out" | grep -q '://' && fail "disabled env emitted a proxy URL"
"$PROXY" curl-args | grep -qx -- '--noproxy'

# HTTP and SOCKS5 rendering, plus the local bypass.
"$PROXY" set 1 http proxy.example 8080
"$PROXY" curl-args > "$work/http.args"
grep -qx 'http://proxy.example:8080' "$work/http.args"
grep -qx 'localhost,127.0.0.1,::1' "$work/http.args"
"$PROXY" set 1 socks5 proxy.example 1080
"$PROXY" env | grep -q "socks5h://proxy.example:1080" || fail "socks5h URL"
"$PROXY" env | grep -q 'no_proxy='"'"'localhost,127.0.0.1,::1'"'" || fail "no_proxy"

# Malformed protocol, host, and port are rejected or fail closed.
"$PROXY" set 1 ftp proxy.example 80 >/dev/null 2>&1 && fail "ftp protocol accepted"
"$PROXY" set 1 http '' 80 >/dev/null 2>&1 && fail "empty host accepted"
"$PROXY" set 1 http proxy.example 0 >/dev/null 2>&1 && fail "port 0 accepted"
"$PROXY" set 1 http proxy.example 65536 >/dev/null 2>&1 && fail "port 65536 accepted"
"$PROXY" set 1 http 'bad;host' 80 >/dev/null 2>&1 && fail "host metacharacter accepted"
printf '%s\n' 'enabled=1' 'protocol=ftp' 'host=a' 'port=1' > "$ZLYME_PROXY_CONF"
"$PROXY" env | grep -q '://' && fail "malformed config emitted a proxy URL"
"$PROXY" get | grep -qx 'enabled=0'
"$PROXY" get | grep -qx 'valid=0'
# A hand-written bad file is mode-independent; a set() file is restrictive.
"$PROXY" set 0 http proxy.example 8080
stat -c %a "$ZLYME_PROXY_CONF" | grep -qx 640 || fail "proxy.conf mode"

# Settings keeps its visible name and sorts first. Other names stay alpha.
map=$ROOT/package/system/nextui/paks/Tools/map.txt
grep -qx 'Settings.pak	000) Settings' "$map" || fail "Settings map line"
python3 - "$map" << 'PY'
import sys
line = open(sys.argv[1], encoding="utf-8").read().strip("\n")
name, alias = line.split("\t", 1)
assert name == "Settings.pak"
assert alias == "000) Settings"

def trim(s):
    i = 0
    while i < len(s) and s[i].isdigit():
        i += 1
    if i < len(s) and s[i] == ")":
        i += 1
        while i < len(s) and s[i] in " \t":
            i += 1
        return s[i:]
    return s

assert trim(alias) == "Settings"
names = [
    "Files.pak",
    "Moonlight.pak",
    "Music Player.pak",
    "Overlays.pak",
    "PortMaster.pak",
    alias,
    "ZcrapeGoat.pak",
]
ordered = sorted(names, key=str.lower)
assert ordered[0] == alias, ordered
rest = [trim(n) if n == alias else n.replace(".pak", "") for n in ordered[1:]]
assert rest == sorted(rest, key=str.lower)
PY

# An existing card map keeps other lines and replaces the Settings alias.
printf '%s\n' 'Files.pak	Files' 'Settings.pak	Settings' 'ZcrapeGoat.pak	Goat' > "$work/card.map"
line=$(grep '^Settings.pak	' "$map")
awk -v line="$line" '
	BEGIN { found = 0 }
	$0 ~ /^Settings\.pak\t/ { print line; found = 1; next }
	{ print }
	END { if (!found) print line }
' "$work/card.map" > "$work/merged.map"
grep -qx 'Files.pak	Files' "$work/merged.map"
grep -qx 'Settings.pak	000) Settings' "$work/merged.map"
grep -qx 'ZcrapeGoat.pak	Goat' "$work/merged.map"
grep -q ensure_tools_map "$ROOT/package/system/nextui/nextui-session"
grep -q 'zlyme-proxy env' "$ROOT/package/system/nextui/nextui-session"

# Updater classification allows reinstall. Notes status is three-way.
# The body file is the full text, not a ten-line cut.
python3 - << PY
import importlib.util, os, io, contextlib
p = "$ROOT/package/system/nextui/zlyme/github-release.py"
spec = importlib.util.spec_from_file_location("gh", p)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
assert m.notes_status({"body": "hello"}) == "present"
assert m.notes_status({"body": ""}) == "empty"
assert m.notes_status({"body": None}) == "empty"
assert m.notes_status({"body": "", "body_status": "unavailable"}) == "unavailable"
root = "a" * 64
assert m.install_match("zlyme44.2 (2026-10-06)", "zlyme44.2", root, "zlyme44.2 (2026-10-05)", root) == "exact-root"
assert m.install_match("zlyme44.2 (2026-10-06)", "zlyme44.2", "", "zlyme44.2 (2026-10-05)", "b" * 64) == "same-version"
assert m.install_match("zlyme44.2", "zlyme44.2", "", "zlyme44.1", "") == "different"
for value in ("exact-root", "same-version", "different"):
    assert value != "reject"
os.environ["ZLYME_INSTALLED_VERSION"] = "zlyme44.2 (2026-10-01)"
os.environ["ZLYME_INSTALLED_ROOT"] = "c" * 64
m.STAGEDIR = "$work"
m.BODY_FILE = "$work/body.txt"
body = "\n".join("line %d" % i for i in range(30)) + "\n\npara\n"
rel = {"name": "zlyme44.2 (2026-10-06)", "tag_name": "zlyme44.2", "body": body, "prerelease": False}
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    m.emit_rel(rel, False,
        {"name": "zlyme-my355-x.tar", "browser_download_url": "u", "id": 1, "size": 1},
        {"name": "zlyme-my355-x.tar.sha256", "browser_download_url": "s", "id": 2},
        {"TARGET_ROOT_SHA256": "d" * 64})
text = open(m.BODY_FILE, encoding="utf-8").read()
assert text == body, "body was truncated"
out = buf.getvalue()
assert "BODY_STATUS=present" in out
assert "MATCH=same-version" in out
assert text.count("\n") >= 31
PY

# The pinned checkout, when present, must not keep the ten-line cut.
nextui=${ZLYME_NEXTUI_SRC:-/run/media/ale/SPCC/Cursor/MIYOO-FLIP/NextUI}
notes=$nextui/workspace/all/settings/zlymeupdate.cpp
list=$nextui/workspace/all/nextui/nextui.c
if [ -f "$notes" ]; then
	grep -q 'lines < 10' "$notes" && fail "release notes still truncate at ten lines"
	grep -q 'Release notes could not be retrieved.' "$notes" || fail "missing unavailable sentence"
	grep -q 'No notes in this release.' "$notes" || fail "missing empty-notes sentence"
	grep -q 'This release version is already installed.' "$notes" || fail "missing same-version warning"
	grep -q 'This exact firmware is already installed.' "$notes" || fail "missing exact-root warning"
	grep -q 'Download/reinstall it anyway?' "$notes" || fail "reinstall is not offered"
	grep -q 'BTN_L1' "$notes" || fail "notes view has no page keys"
	grep -q 'same_running_build' "$notes" && fail "date heuristic is still the decision"
fi
if [ -f "$list" ]; then
	grep -n 'trimSortingMeta(&entry->name)' "$list" && fail "sort key is stripped in place"
	grep -n 'trimSortingMeta(&entry->unique)' "$list" && fail "unique sort key is stripped in place"
fi

# Live log: full file kept, console filtered, producer status preserved.
log=$work/build.log
set +e
console=$(bash "$ROOT/scripts/ci/stream-build-log.sh" "$log" sh -c 'echo ">>> pkg 1 Building"; echo noise; echo "make: *** [all] Error 2"; exit 9')
rc=$?
set -e
[ "$rc" = 9 ] || fail "build status became $rc"
printf '%s\n' "$console" | grep -q '>>> pkg 1 Building' || fail "progress line missing"
printf '%s\n' "$console" | grep -q noise && fail "noise reached the console"
grep -q noise "$log" || fail "full log dropped a line"
set +e
bash "$ROOT/scripts/ci/stream-build-log.sh" "$log" sh -c 'echo quiet; exit 0' >/dev/null
rc=$?
set -e
[ "$rc" = 0 ] || fail "successful build became $rc"
set +e
bash "$ROOT/scripts/ci/stream-build-log.sh" "$log" sh -c 'echo quiet; exit 4' >/dev/null
rc=$?
set -e
[ "$rc" = 4 ] || fail "failed build became $rc"

stage=$ROOT/.github/workflows/build-stage.yml
grep -q 'scripts/ci/stream-build-log.sh' "$stage" || fail "workflow does not stream"
grep -q 'path: output/zlyme-build.log' "$stage" || fail "full log artifact removed"
grep -q '124|137|143' "$stage" || fail "timeout continue removed"
# Host tests are not packaged.
if grep -RIn 'scripts/tests' "$ROOT/package" "$ROOT/board" >/dev/null 2>&1; then
	fail "a package or board script references scripts/tests"
fi

echo phase11a-ok
