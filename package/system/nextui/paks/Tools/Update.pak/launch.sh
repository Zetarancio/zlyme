#!/bin/sh
# Queue a GitHub *release* tar as the well-known OTA name, then reboot.
# Actions artifacts are not visible here. Run workflow_dispatch so the
# release job publishes /releases/latest.
printf '%s' /storage > /tmp/last.txt

PAK_DIR="$(dirname "$0")"
cd "$PAK_DIR" || exit 1

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

auth=""
[ -n "$tok" ] && auth="-H Authorization: Bearer $tok"

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

# Probe without -f so a 404 is "no release", not a generic curl fail.
# Downloads can be ~600 MB on Wi-Fi; 180 s was too short.
CURL_META="curl -sS -L --connect-timeout 15 --max-time 30 $caflag $auth"
CURL_GET="curl -fL --connect-timeout 15 --max-time 7200 --retry 2 $caflag"

command -v curl >/dev/null 2>&1 || fail "curl is missing"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is missing"

mkdir -p "$STAGEDIR" || fail "cannot write $STAGEDIR"

msg "Checking for update..."
api="https://api.github.com/repos/${repo}/releases/latest"
json_tmp="$STAGEDIR/.latest.json"
http=$($CURL_META -o "$json_tmp" -w '%{http_code}' "$api") || http=000
json=""
[ -f "$json_tmp" ] && json=$(cat "$json_tmp")
rm -f "$json_tmp"

case "$http" in
	200) ;;
	401|403)
		fail "GitHub denied the API. Put a repo PAT in /storage/.config/github-token"
		;;
	404)
		fail "No GitHub release yet. Actions → Build → Run workflow"
		;;
	000)
		fail "GitHub API failed (network)"
		;;
	*)
		fail "GitHub API HTTP $http"
		;;
esac

# One GitHub asset object per line (split on '{'). Patterns are
# literals in case, not a $glob variable (ash vs bash vs zsh).
asset_line() {
	kind=$1
	printf '%s\n' "$json" | tr '{' '\n' | while IFS= read -r line; do
		name=$(printf '%s' "$line" | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p')
		[ -n "$name" ] || continue
		ok=0
		case "$kind" in
			tar)
				case "$name" in
					zlyme-my355-*.tar)
						case "$name" in *.sha256) ;; *) ok=1 ;; esac
						;;
				esac
				;;
			sha)
				case "$name" in
					zlyme-my355-*.tar.sha256|zlyme-my355-*.sha256) ok=1 ;;
				esac
				;;
		esac
		[ "$ok" = 1 ] || continue
		id=$(printf '%s' "$line" | sed -n 's/.*"id": *\([0-9][0-9]*\).*/\1/p')
		url=$(printf '%s' "$line" | sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p')
		printf '%s %s %s\n' "$id" "$name" "$url"
		break
	done
}

tar_info=$(asset_line tar)
sha_info=$(asset_line sha)

[ -n "$tar_info" ] || fail "No zlyme-my355-*.tar in latest release"
[ -n "$sha_info" ] || fail "No sha256 next to that tar"

tar_id=$(printf '%s\n' "$tar_info" | awk '{print $1}')
tar_base=$(printf '%s\n' "$tar_info" | awk '{print $2}')
tar_url=$(printf '%s\n' "$tar_info" | awk '{print $3}')
sha_id=$(printf '%s\n' "$sha_info" | awk '{print $1}')
sha_base=$(printf '%s\n' "$sha_info" | awk '{print $2}')
sha_url=$(printf '%s\n' "$sha_info" | awk '{print $3}')

tar_tmp="$STAGEDIR/$tar_base"
sha_tmp="$STAGEDIR/$sha_base"

fetch_asset() {
	out=$1
	id=$2
	url=$3
	if [ -n "$tok" ] && [ -n "$id" ] && [ "$id" != "0" ]; then
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

# One payload on disk: rename the verified tar to the boot-path name.
rm -f "$QUEUED"
mv -f "$tar_tmp" "$QUEUED" || fail "Could not queue update"
rm -f "$sha_tmp"
# Versioned leftovers only (YYYYMMDD-...). Do not glob zlyme-my355-update.tar.
rm -f "$STAGEDIR"/zlyme-my355-[0-9]*.tar \
	"$STAGEDIR"/zlyme-my355-[0-9]*.sha256 \
	"$STAGEDIR"/zlyme-my355-[0-9]*.tar.sha256 2>/dev/null || true
sync

msg "Rebooting to apply..."
reboot -f 2>/dev/null || reboot
exit 0
