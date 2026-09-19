#!/bin/sh
# Queue a GitHub *release* tar as the well-known OTA name, then reboot.
# Public /releases/latest does not need a PAT. A token is only used if
# GitHub returns 401/403.
printf '%s' /storage > /tmp/last.txt
# Comment out to skip this pak's log (About → System logs).
[ -r /usr/share/nextui/bin/pak-log.sh ] && . /usr/share/nextui/bin/pak-log.sh

PAK_DIR="$(dirname "$0")"
cd "$PAK_DIR" || exit 1

command -v zlyme-governor >/dev/null 2>&1 && zlyme-governor play >/dev/null 2>&1 || true

STAGEDIR=/storage/.update
QUEUED="$STAGEDIR/zlyme-my355-update.tar"
REPO_FILE=/usr/share/zlyme/github-repo
TOKEN_FILE=/storage/.config/github-token

msg() {
	echo "$1"
	if command -v show.elf >/dev/null 2>&1; then
		show.elf "$1" 3
	else
		sleep 2
	fi
}

fail() {
	msg "$1"
	exit 0
}

repo=""
if [ -r "$REPO_FILE" ]; then
	repo=$(tr -d ' \t\r\n' < "$REPO_FILE")
fi
case "$repo" in
	""|OWNER/REPO|owner/repo)
		fail "Set GitHub repo in /usr/share/zlyme/github-repo"
		;;
esac

tok=""
if [ -r "$TOKEN_FILE" ]; then
	tok=$(tr -d ' \t\r\n' < "$TOKEN_FILE")
fi

caflag=""
for ca in /etc/ssl/certs/ca-certificates.crt \
          /etc/pki/tls/certs/ca-bundle.crt \
          /etc/ssl/cert.pem; do
	if [ -f "$ca" ]; then
		caflag="--cacert $ca"
		break
	fi
done
[ -n "$caflag" ] || caflag="--insecure"

CURL_META="curl -sS -L --connect-timeout 15 --max-time 30 -A zlyme-update $caflag"
CURL_GET="curl -fL --connect-timeout 15 --max-time 7200 --retry 2 -A zlyme-update $caflag"

command -v curl >/dev/null 2>&1 || fail "curl is missing"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is missing"
command -v python3 >/dev/null 2>&1 || fail "python3 is missing"

mkdir -p "$STAGEDIR" || fail "cannot write $STAGEDIR"

api_latest="https://api.github.com/repos/${repo}/releases/latest"
api_list="https://api.github.com/repos/${repo}/releases?per_page=20"
atom_url="https://github.com/${repo}/releases.atom"
json_tmp="$STAGEDIR/.latest.json"
atom_tmp="$STAGEDIR/.releases.atom"
html_tmp="$STAGEDIR/.assets.html"

fetch_json() {
	url=$1
	auth=$2
	rm -f "$json_tmp"
	if [ -n "$auth" ]; then
		$CURL_META -H "Authorization: Bearer $tok" -o "$json_tmp" -w '%{http_code}' "$url"
	else
		$CURL_META -o "$json_tmp" -w '%{http_code}' "$url"
	fi
}

# /releases/latest ignores prereleases (404 when the only build is a prerelease).
normalize_release() {
	python3 - "$json_tmp" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write("json: %s\n" % e)
    sys.exit(1)

rel = None
if isinstance(data, dict) and data.get("assets") is not None and data.get("tag_name"):
    rel = data
elif isinstance(data, list):
    published = [r for r in data if isinstance(r, dict) and not r.get("draft")]
    stable = [r for r in published if not r.get("prerelease")]
    pool = stable or published
    rel = pool[0] if pool else None

if not rel:
    sys.exit(2)
with open(path, "w", encoding="utf-8") as f:
    json.dump(rel, f)
print(rel.get("tag_name") or "")
PY
}

# GitHub HTML/atom does not use the REST rate limit. Atom has the tag
# even when it is a prerelease; expanded_assets lists the tar names.
scrape_html_release() {
	rm -f "$atom_tmp" "$html_tmp"
	atom_http=$($CURL_META -o "$atom_tmp" -w '%{http_code}' "$atom_url") || atom_http=000
	[ "$atom_http" = 200 ] || return 1
	tag=$(python3 - "$atom_tmp" <<'PY'
import re, sys
text = open(sys.argv[1], "r", encoding="utf-8", errors="replace").read()
m = re.search(r"/releases/tag/([^<>\"\s]+)", text)
if not m:
    sys.exit(1)
print(m.group(1))
PY
) || return 1
	[ -n "$tag" ] || return 1
	exp_http=$($CURL_META -o "$html_tmp" -w '%{http_code}' \
		"https://github.com/${repo}/releases/expanded_assets/${tag}") || exp_http=000
	[ "$exp_http" = 200 ] || return 1
	python3 - "$html_tmp" "$json_tmp" "$tag" "$repo" <<'PY'
import json, re, sys
html, out, tag, repo = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = open(html, "r", encoding="utf-8", errors="replace").read()
hrefs = re.findall(r'href="([^"]+/releases/download/[^"]+)"', text)
assets = []
for href in hrefs:
    if href.startswith("/"):
        url = "https://github.com" + href
    else:
        url = href
    name = url.rsplit("/", 1)[-1]
    assets.append({"id": 0, "name": name, "browser_download_url": url})
if not any(
    a["name"].startswith("zlyme-my355-") and a["name"].endswith(".tar")
    and not a["name"].endswith(".sha256")
    for a in assets
):
    sys.exit(1)
json.dump({"tag_name": tag, "assets": assets, "prerelease": True}, open(out, "w"))
print(tag)
PY
}

msg "Checking for update..."
use_auth=""
http=$(fetch_json "$api_latest" "") || http=000
case "$http" in
	401|403)
		if [ -n "$tok" ]; then
			http=$(fetch_json "$api_latest" auth) || http=000
			use_auth=1
		fi
		;;
	404)
		auth_arg=""
		[ -n "$use_auth" ] && auth_arg=auth
		http=$(fetch_json "$api_list" "$auth_arg") || http=000
		;;
esac

rel_tag=""
if [ "$http" = 200 ]; then
	rel_tag=$(normalize_release) || rel_tag=""
fi
if [ -z "$rel_tag" ]; then
	# 404 (prerelease-only) or 403 (unauthenticated API quota) → HTML.
	rel_tag=$(scrape_html_release) || fail "No GitHub release yet. Actions → Build → Run workflow"
fi

asset_line() {
	kind=$1
	python3 - "$json_tmp" "$kind" <<'PY'
import json, sys
path, kind = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write("json: %s\n" % e)
    sys.exit(1)
assets = data.get("assets") or []
for a in assets:
    name = a.get("name") or ""
    ok = False
    if kind == "tar":
        if name.startswith("zlyme-my355-") and name.endswith(".tar") and not name.endswith(".sha256"):
            ok = True
    elif kind == "sha":
        if name.startswith("zlyme-my355-") and (
            name.endswith(".tar.sha256") or name.endswith(".sha256")
        ):
            ok = True
    if not ok:
        continue
    aid = a.get("id") or 0
    url = a.get("browser_download_url") or ""
    print("%s %s %s" % (aid, name, url))
    break
PY
}

tar_info=$(asset_line tar)
sha_info=$(asset_line sha)
rm -f "$json_tmp" "$atom_tmp" "$html_tmp"

[ -n "$tar_info" ] || fail "No zlyme-my355-*.tar in latest release"
[ -n "$sha_info" ] || fail "No sha256 next to that tar"

tar_base=$(printf '%s\n' "$tar_info" | awk '{print $2}')
if [ "${1:-}" = "--check" ] || [ "${ZLYME_UPDATE_CHECK_ONLY:-}" = "1" ]; then
	msg "Found $tar_base${rel_tag:+ ($rel_tag)}"
	exit 0
fi

tar_id=$(printf '%s\n' "$tar_info" | awk '{print $1}')
tar_base=$(printf '%s\n' "$tar_info" | awk '{print $2}')
tar_url=$(printf '%s\n' "$tar_info" | awk '{print $3}')
sha_id=$(printf '%s\n' "$sha_info" | awk '{print $1}')
sha_base=$(printf '%s\n' "$sha_info" | awk '{print $2}')
sha_url=$(printf '%s\n' "$sha_info" | awk '{print $3}')

tar_tmp="$STAGEDIR/$tar_base"
sha_tmp="$STAGEDIR/$sha_base"

auth=""
[ -n "$use_auth" ] && [ -n "$tok" ] && auth="-H Authorization: Bearer $tok"

fetch_asset() {
	out=$1
	id=$2
	url=$3
	if [ -n "$use_auth" ] && [ -n "$id" ] && [ "$id" != "0" ]; then
		$CURL_GET $auth -H "Accept: application/octet-stream" \
			-o "$out" "https://api.github.com/repos/${repo}/releases/assets/${id}"
		return $?
	fi
	[ -n "$url" ] || return 1
	$CURL_GET $auth -o "$out" "$url"
}

msg "Downloading $tar_base (several minutes)..."
fetch_asset "$tar_tmp" "$tar_id" "$tar_url" || {
	rm -f "$tar_tmp"
	fail "Download failed"
}
fetch_asset "$sha_tmp" "$sha_id" "$sha_url" || {
	rm -f "$tar_tmp" "$sha_tmp"
	fail "Checksum download failed"
}

(
	cd "$STAGEDIR" || exit 1
	sha256sum -c "$sha_base"
) || {
	rm -f "$tar_tmp" "$sha_tmp"
	fail "Hash mismatch"
}

rm -f "$QUEUED"
mv -f "$tar_tmp" "$QUEUED" || fail "Could not queue update"
rm -f "$sha_tmp"
rm -f "$STAGEDIR"/zlyme-my355-[0-9]*.tar \
	"$STAGEDIR"/zlyme-my355-[0-9]*.sha256 \
	"$STAGEDIR"/zlyme-my355-[0-9]*.tar.sha256 2>/dev/null || true
sync

msg "Rebooting to apply..."
reboot -f 2>/dev/null || reboot
exit 0
