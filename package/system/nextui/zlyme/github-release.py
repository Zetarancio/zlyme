#!/usr/bin/python3
# Resolve the GitHub release tar + sha256 for Settings → Update.
# Prints KEY=value lines (no JSON on stdout). Body goes to BODY_FILE.
import argparse
import json
import os
import re
import subprocess
import sys

REPO_FILE = "/usr/share/zlyme/github-repo"
TOKEN_FILE = "/storage/.config/github-token"
STAGEDIR = "/storage/.update"
JSON_TMP = os.path.join(STAGEDIR, ".latest.json")
ATOM_TMP = os.path.join(STAGEDIR, ".releases.atom")
HTML_TMP = os.path.join(STAGEDIR, ".assets.html")
BODY_FILE = os.path.join(STAGEDIR, ".release-body.txt")


def die(msg):
    sys.stdout.write("OK=0\nERROR=%s\n" % msg.replace("\n", " ").strip())
    sys.exit(0)


def read_one(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip().replace("\r", "").replace("\n", "").replace(" ", "")
    except OSError:
        return ""


def ca_args():
    for p in (
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/cert.pem",
    ):
        if os.path.isfile(p):
            return ["--cacert", p]
    return ["--insecure"]


def curl_meta():
    return [
        "curl",
        "-sS",
        "-L",
        "--connect-timeout",
        "15",
        "--max-time",
        "30",
        "-A",
        "zlyme-update",
    ] + ca_args()


def http_get(url, dest, token=""):
    cmd = curl_meta()
    if token:
        cmd += ["-H", "Authorization: Bearer %s" % token]
    cmd += ["-o", dest, "-w", "%{http_code}", url]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        return "000", str(e)
    code = (p.stdout or "").strip() or "000"
    return code, p.stderr or ""


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def pick_release(data, channel):
    if isinstance(data, dict) and data.get("assets") is not None and data.get("tag_name"):
        if channel == "releases" and data.get("prerelease"):
            return None
        return data
    if not isinstance(data, list):
        return None
    published = [r for r in data if isinstance(r, dict) and not r.get("draft")]
    if channel == "releases":
        pool = [r for r in published if not r.get("prerelease")]
    else:
        pool = published
    return pool[0] if pool else None


def find_assets(rel):
    tar_a = None
    sha_a = None
    for a in rel.get("assets") or []:
        name = a.get("name") or ""
        if (
            name.startswith("zlyme-my355-")
            and name.endswith(".tar")
            and not name.endswith(".sha256")
            and tar_a is None
        ):
            tar_a = a
        elif name.startswith("zlyme-my355-") and (
            name.endswith(".tar.sha256") or name.endswith(".sha256")
        ):
            if sha_a is None:
                sha_a = a
    return tar_a, sha_a


def scrape_html(repo):
    atom_url = "https://github.com/%s/releases.atom" % repo
    try:
        os.remove(ATOM_TMP)
    except OSError:
        pass
    try:
        os.remove(HTML_TMP)
    except OSError:
        pass
    code, _ = http_get(atom_url, ATOM_TMP)
    if code != "200":
        return None
    text = open(ATOM_TMP, "r", encoding="utf-8", errors="replace").read()
    m = re.search(r"/releases/tag/([^<>\"\s]+)", text)
    if not m:
        return None
    tag = m.group(1)
    exp = "https://github.com/%s/releases/expanded_assets/%s" % (repo, tag)
    code, _ = http_get(exp, HTML_TMP)
    if code != "200":
        return None
    html = open(HTML_TMP, "r", encoding="utf-8", errors="replace").read()
    hrefs = re.findall(r'href="([^"]+/releases/download/[^"]+)"', html)
    assets = []
    for href in hrefs:
        url = ("https://github.com" + href) if href.startswith("/") else href
        name = url.rsplit("/", 1)[-1]
        assets.append(
            {
                "id": 0,
                "name": name,
                "browser_download_url": url,
                "size": 0,
            }
        )
    if not any(
        a["name"].startswith("zlyme-my355-")
        and a["name"].endswith(".tar")
        and not a["name"].endswith(".sha256")
        for a in assets
    ):
        return None
    return {"tag_name": tag, "assets": assets, "prerelease": True, "body": ""}


def emit_rel(rel, use_auth):
    tar_a, sha_a = find_assets(rel)
    if not tar_a:
        die("No zlyme-my355-*.tar in this release")
    if not sha_a:
        die("No sha256 next to that tar")
    body = rel.get("body") or ""
    os.makedirs(STAGEDIR, exist_ok=True)
    with open(BODY_FILE, "w", encoding="utf-8") as f:
        f.write(body)
    tag = rel.get("tag_name") or ""
    name = (rel.get("name") or "").replace("\n", " ").replace("\r", "")
    pre = 1 if rel.get("prerelease") else 0
    tar_id = tar_a.get("id") or 0
    sha_id = sha_a.get("id") or 0
    tar_size = tar_a.get("size") or 0
    sys.stdout.write("OK=1\n")
    sys.stdout.write("ERROR=\n")
    sys.stdout.write("TAG=%s\n" % tag)
    sys.stdout.write("NAME=%s\n" % name)
    sys.stdout.write("PRERELEASE=%s\n" % pre)
    sys.stdout.write("USE_AUTH=%s\n" % (1 if use_auth else 0))
    sys.stdout.write("TAR_NAME=%s\n" % (tar_a.get("name") or ""))
    sys.stdout.write("TAR_URL=%s\n" % (tar_a.get("browser_download_url") or ""))
    sys.stdout.write("TAR_ID=%s\n" % tar_id)
    sys.stdout.write("TAR_SIZE=%s\n" % tar_size)
    sys.stdout.write("SHA_NAME=%s\n" % (sha_a.get("name") or ""))
    sys.stdout.write("SHA_URL=%s\n" % (sha_a.get("browser_download_url") or ""))
    sys.stdout.write("SHA_ID=%s\n" % sha_id)
    sys.stdout.write("BODY_FILE=%s\n" % BODY_FILE)


def main():
    ap = argparse.ArgumentParser(description="Zlyme GitHub OTA metadata")
    ap.add_argument(
        "--channel",
        default="releases",
        choices=("releases", "prereleases"),
    )
    args = ap.parse_args()
    channel = args.channel

    repo = read_one(REPO_FILE)
    if not repo or repo.lower() in ("owner/repo",):
        die("Set GitHub repo in /usr/share/zlyme/github-repo")

    tok = read_one(TOKEN_FILE)
    os.makedirs(STAGEDIR, exist_ok=True)

    api_latest = "https://api.github.com/repos/%s/releases/latest" % repo
    api_list = "https://api.github.com/repos/%s/releases?per_page=20" % repo

    use_auth = False
    rel = None

    def fetch(url, auth):
        try:
            os.remove(JSON_TMP)
        except OSError:
            pass
        return http_get(url, JSON_TMP, tok if auth else "")

    if channel == "prereleases":
        urls = [api_list]
    else:
        urls = [api_latest, api_list]

    http = "000"
    for url in urls:
        http, _ = fetch(url, False)
        if http in ("401", "403") and tok:
            http, _ = fetch(url, True)
            use_auth = http == "200"
        if http == "200":
            try:
                data = load_json(JSON_TMP)
            except Exception as e:
                die("json: %s" % e)
            rel = pick_release(data, channel)
            if rel:
                break
        if channel == "releases" and url == api_latest and http == "404":
            continue
        if http in ("401", "403", "404"):
            continue
        if http != "200":
            break

    if not rel:
        if channel == "releases" and http == "200":
            die("No stable release yet. Switch channel to Prereleases")
        scraped = scrape_html(repo)
        if not scraped:
            die("No GitHub release yet. Actions, Build, Run workflow")
        rel = scraped

    tar_a, sha_a = find_assets(rel)
    if not tar_a or not sha_a:
        die("No zlyme-my355-*.tar in this release" if not tar_a else "No sha256 next to that tar")

    emit_rel(rel, use_auth)
    for p in (JSON_TMP, ATOM_TMP, HTML_TMP):
        try:
            os.remove(p)
        except OSError:
            pass


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        die(str(e))
