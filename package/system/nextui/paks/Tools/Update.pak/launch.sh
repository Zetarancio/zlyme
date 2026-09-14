#!/bin/sh
# Queue a GitHub release tar as the well-known OTA name, then reboot.
printf '%s' /storage > /tmp/last.txt

PAK_DIR="$(dirname "$0")"
cd "$PAK_DIR" || exit 1

STAGEDIR=/storage/.update
QUEUED="$STAGEDIR/zlyme-my355-update.tar"
REPO_FILE=/usr/share/zlyme/github-repo

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

CURL="curl -fsSL --connect-timeout 15 --max-time 180"
TOKEN_FILE=/storage/.config/github-token
if [ -r "$TOKEN_FILE" ]; then
	tok=$(tr -d ' \t\r\n' < "$TOKEN_FILE")
	[ -n "$tok" ] && CURL="$CURL -H Authorization: Bearer $tok"
fi
for ca in /etc/ssl/certs/ca-certificates.crt \
          /etc/pki/tls/certs/ca-bundle.crt \
          /etc/ssl/cert.pem; do
	if [ -f "$ca" ]; then
		CURL="$CURL --cacert $ca"
		HAS_CA=1
		break
	fi
done
if [ -z "${HAS_CA:-}" ]; then
	CURL="$CURL --insecure"
fi

command -v curl >/dev/null 2>&1 || fail "curl is missing"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is missing"

mkdir -p "$STAGEDIR" || fail "cannot write $STAGEDIR"

msg "Checking for update..."
api="https://api.github.com/repos/${repo}/releases/latest"
json=$($CURL "$api") || fail "GitHub API failed"

# One asset URL per line. Pick the versioned tar and its checksum.
urls=$(printf '%s\n' "$json" | tr ',' '\n' | sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p')
tar_url=$(printf '%s\n' "$urls" | grep -E '/zlyme-my355-[^/]+\.tar$' | head -n 1)
sha_url=$(printf '%s\n' "$urls" | grep -E '/zlyme-my355-[^/]+\.tar\.sha256$' | head -n 1)
if [ -z "$sha_url" ]; then
	sha_url=$(printf '%s\n' "$urls" | grep -E '/zlyme-my355-[^/]+\.sha256$' | head -n 1)
fi
[ -n "$tar_url" ] || fail "No zlyme-my355-*.tar in latest release"
[ -n "$sha_url" ] || fail "No sha256 next to that tar"

tar_base=$(basename "$tar_url")
sha_base=$(basename "$sha_url")
tar_tmp="$STAGEDIR/$tar_base"
sha_tmp="$STAGEDIR/$sha_base"

msg "Downloading $tar_base..."
$CURL -o "$tar_tmp" "$tar_url" || {
	rm -f "$tar_tmp"
	fail "Download failed"
}
$CURL -o "$sha_tmp" "$sha_url" || {
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
