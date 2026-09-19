extern "C"
{
#include "msettings.h"
#include "defines.h"
#include "api.h"
#include "utils.h"
}

#include "zlymeupdate.hpp"

#include <curl/curl.h>

#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iterator>
#include <mutex>
#include <strings.h>
#include <string>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <thread>
#include <unistd.h>
#include <vector>

namespace {

const char *kStageDir = "/storage/.update";
const char *kQueuedTar = "/storage/.update/zlyme-my355-update.tar";
const char *kQueuedName = "/storage/.update/NAME";
const char *kFailedDir = "/storage/.update/failed";
const char *kFailedNote = "/storage/.update/FAILED";
const char *kHelper = "/usr/share/zlyme/github-release.py";
const char *kTokenFile = "/storage/.config/github-token";
const long long kSlackBytes = 50LL * 1024 * 1024;
const int kMinBatteryPct = 20;

struct ReleaseMeta {
    bool ok = false;
    std::string error;
    std::string tag;
    std::string name;
    bool prerelease = false;
    bool use_auth = false;
    std::string tar_name;
    std::string tar_url;
    long tar_id = 0;
    long long tar_size = 0;
    std::string sha_name;
    std::string sha_url;
    long sha_id = 0;
    std::string body;
};

ReleaseMeta g_rel;

std::string trim(std::string s)
{
    while (!s.empty() && (s.back() == '\n' || s.back() == '\r' || s.back() == ' ' || s.back() == '\t'))
        s.pop_back();
    size_t i = 0;
    while (i < s.size() && (s[i] == ' ' || s[i] == '\t'))
        i++;
    return s.substr(i);
}

std::string read_file(const char *path)
{
    std::ifstream in(path);
    if (!in)
        return "";
    std::string s((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    return s;
}

std::string read_first_line(const char *path)
{
    std::ifstream in(path);
    if (!in)
        return "";
    std::string s;
    std::getline(in, s);
    return trim(s);
}

void write_file(const char *path, const std::string &s)
{
    std::ofstream out(path, std::ios::trunc);
    if (out)
        out << s << "\n";
}

std::string ctl_get(const char *name)
{
    std::string cmd = std::string("zlyme-ctl get ") + name;
    FILE *f = popen(cmd.c_str(), "r");
    if (!f)
        return "";
    char buf[128] = {0};
    if (!fgets(buf, sizeof(buf), f)) {
        pclose(f);
        return "";
    }
    pclose(f);
    return trim(buf);
}

void ctl_set(const char *name, const char *val)
{
    std::string cmd = std::string("zlyme-ctl set ") + name + " " + val;
    (void)system(cmd.c_str());
}

std::string channel_now()
{
    std::string c = ctl_get("update_channel");
    if (c != "prereleases")
        c = "releases";
    return c;
}

std::string installed_version()
{
    std::ifstream in("/etc/os-release");
    std::string line, ver;
    while (std::getline(in, line)) {
        if (line.rfind("VERSION=", 0) == 0) {
            ver = line.substr(8);
            if (!ver.empty() && ver.front() == '"') {
                ver.erase(0, 1);
                if (!ver.empty() && ver.back() == '"')
                    ver.pop_back();
            }
            break;
        }
    }
    if (ver.empty())
        ver = trim(read_file("/usr/share/zlyme/version"));
    return ver.empty() ? "unknown" : ver;
}

std::string fmt_mb(long long n)
{
    if (n <= 0)
        return "? MB";
    char buf[32];
    snprintf(buf, sizeof(buf), "%lld MB", (n + 512 * 1024) / (1024 * 1024));
    return buf;
}

long long storage_free()
{
    struct statvfs st;
    if (statvfs("/storage", &st) != 0)
        return 0;
    return (long long)st.f_bavail * (long long)st.f_frsize;
}

long long file_size(const std::string &path)
{
    struct stat st;
    if (stat(path.c_str(), &st) != 0)
        return 0;
    return (long long)st.st_size;
}

bool file_exists(const char *path)
{
    return access(path, F_OK) == 0;
}

std::string token_now()
{
    return read_first_line(kTokenFile);
}

std::string ca_path()
{
    const char *cands[] = {
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/cert.pem",
        nullptr,
    };
    for (int i = 0; cands[i]; i++) {
        if (file_exists(cands[i]))
            return cands[i];
    }
    return "";
}

void overlay_ok(const std::string &msg)
{
    MenuList::showOverlay(msg, OverlayDismissMode::DismissOnA);
}

int wait_ab(const std::string &msg, const char *aLabel, const char *bLabel)
{
    for (;;) {
        GFX_startFrame();
        PAD_poll();
        if (PAD_justPressed(BTN_A)) {
            MenuList::hideOverlay();
            return 1;
        }
        if (PAD_justPressed(BTN_B)) {
            MenuList::hideOverlay();
            return 0;
        }
        MenuList::showOverlayAB(msg, aLabel, bLabel);
        GFX_sync();
    }
}

void clear_failed_slot()
{
    std::string cmd = std::string("rm -rf ") + kFailedDir + " " + kFailedNote;
    (void)system(cmd.c_str());
}

std::string tar_date_compact(const std::string &tar)
{
    const size_t plen = 12;
    if (tar.size() < plen + 8 || tar.compare(0, plen, "zlyme-my355-") != 0)
        return "";
    for (size_t i = 0; i < 8; i++) {
        if (!isdigit((unsigned char)tar[plen + i]))
            return "";
    }
    return tar.substr(plen, 8);
}

// zlyme-my355-YYYYMMDD-*.tar → YYYY-MM-DD
std::string short_build_id(const std::string &tar)
{
    std::string d = tar_date_compact(tar);
    if (d.size() != 8)
        return "";
    return d.substr(0, 4) + "-" + d.substr(4, 2) + "-" + d.substr(6, 2);
}

std::string zlyme_ver_from_tag(const std::string &tag)
{
    auto pos = tag.rfind("zlyme");
    if (pos == std::string::npos)
        return "";
    std::string v = tag.substr(pos);
    size_t n = 5;
    while (n < v.size() && isalnum((unsigned char)v[n]))
        n++;
    v = v.substr(0, n);
    return v.size() > 5 ? v : "";
}

std::string date_in_parens(const std::string &s)
{
    auto a = s.find('(');
    auto b = s.rfind(')');
    if (a == std::string::npos || b == std::string::npos || b <= a + 1)
        return "";
    std::string inner = trim(s.substr(a + 1, b - a - 1));
    if (inner.size() == 10 && inner[4] == '-' && inner[7] == '-')
        return inner;
    return "";
}

// Same shape as /etc/os-release VERSION: zlyme40 (2026-09-19)
std::string short_rel_label()
{
    std::string zv = zlyme_ver_from_tag(g_rel.name);
    if (zv.empty())
        zv = zlyme_ver_from_tag(g_rel.tag);
    std::string date = date_in_parens(g_rel.name);
    if (date.empty())
        date = short_build_id(g_rel.tar_name);
    if (!zv.empty() && !date.empty())
        return zv + " (" + date + ")";
    if (!zv.empty())
        return zv;
    if (!date.empty())
        return date;
    if (!g_rel.name.empty())
        return g_rel.name;
    return "update";
}

bool same_running_build()
{
    if (g_rel.tar_name.empty())
        return false;
    std::string inst = installed_version();
    std::string id = short_build_id(g_rel.tar_name);
    if (!id.empty() && inst.find(id) != std::string::npos)
        return true;
    std::string compact = tar_date_compact(g_rel.tar_name);
    return !compact.empty() && inst.find(compact) != std::string::npos;
}

struct StayAwake {
    StayAwake()
    {
        PWR_disableAutosleep();
        PWR_disableSleep();
        (void)system("killall -STOP zlyme-keylidmon >/dev/null 2>&1");
    }
    ~StayAwake()
    {
        PWR_enableSleep();
        PWR_enableAutosleep();
        (void)system("killall -CONT zlyme-keylidmon >/dev/null 2>&1");
    }
};

ReleaseMeta parse_meta(const std::string &text)
{
    ReleaseMeta m;
    std::string body_file;
    size_t pos = 0;
    while (pos < text.size()) {
        size_t nl = text.find('\n', pos);
        if (nl == std::string::npos)
            nl = text.size();
        std::string line = text.substr(pos, nl - pos);
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        pos = nl + 1;
        size_t eq = line.find('=');
        if (eq == std::string::npos)
            continue;
        std::string k = line.substr(0, eq);
        std::string v = line.substr(eq + 1);
        if (k == "OK")
            m.ok = (v == "1");
        else if (k == "ERROR")
            m.error = v;
        else if (k == "TAG")
            m.tag = v;
        else if (k == "NAME")
            m.name = v;
        else if (k == "PRERELEASE")
            m.prerelease = (v == "1");
        else if (k == "USE_AUTH")
            m.use_auth = (v == "1");
        else if (k == "TAR_NAME")
            m.tar_name = v;
        else if (k == "TAR_URL")
            m.tar_url = v;
        else if (k == "TAR_ID")
            m.tar_id = strtol(v.c_str(), nullptr, 10);
        else if (k == "TAR_SIZE")
            m.tar_size = strtoll(v.c_str(), nullptr, 10);
        else if (k == "SHA_NAME")
            m.sha_name = v;
        else if (k == "SHA_URL")
            m.sha_url = v;
        else if (k == "SHA_ID")
            m.sha_id = strtol(v.c_str(), nullptr, 10);
        else if (k == "BODY_FILE")
            body_file = v;
    }
    if (!body_file.empty())
        m.body = read_file(body_file.c_str());
    return m;
}

ReleaseMeta fetch_meta()
{
    std::string ch = channel_now();
    std::string cmd = std::string("python3 ") + kHelper + " --channel " + ch + " 2>/dev/null";
    FILE *f = popen(cmd.c_str(), "r");
    if (!f) {
        ReleaseMeta m;
        m.error = "python3 is missing";
        return m;
    }
    std::string out;
    char buf[512];
    while (fgets(buf, sizeof(buf), f))
        out += buf;
    pclose(f);
    ReleaseMeta m = parse_meta(out);
    if (!m.ok && m.error.empty())
        m.error = "Check failed";
    return m;
}

std::string available_label()
{
    if (!g_rel.ok) {
        if (g_rel.error.empty())
            return "Check first";
        if (g_rel.error.find("No stable") != std::string::npos)
            return "No stable release";
        if (g_rel.error.find("No GitHub") != std::string::npos)
            return "No release yet";
        if (g_rel.error.size() > 22)
            return "Check failed";
        return g_rel.error;
    }
    return short_rel_label();
}

std::string expected_hash(const std::string &sidecar)
{
    std::ifstream in(sidecar);
    std::string line;
    if (!std::getline(in, line))
        return "";
    size_t i = 0;
    while (i < line.size() && isxdigit((unsigned char)line[i]))
        i++;
    return line.substr(0, i);
}

std::string sha256_of(const std::string &path)
{
    std::string cmd = "sha256sum '" + path + "'";
    FILE *f = popen(cmd.c_str(), "r");
    if (!f)
        return "";
    char buf[160] = {0};
    if (!fgets(buf, sizeof(buf), f)) {
        pclose(f);
        return "";
    }
    pclose(f);
    std::string line = buf;
    size_t i = 0;
    while (i < line.size() && isxdigit((unsigned char)line[i]))
        i++;
    return line.substr(0, i);
}

struct CurlDl {
    std::atomic<int> cancel{0};
    std::atomic<long long> now{0};
    std::atomic<long long> total{0};
    std::atomic<int> done{0};
    std::string error;
    std::mutex err_mu;
    long long resume = 0;
    std::chrono::steady_clock::time_point t0;
};

int xfer_cb(void *p, curl_off_t dltotal, curl_off_t dlnow, curl_off_t, curl_off_t)
{
    auto *s = static_cast<CurlDl *>(p);
    if (s->cancel.load())
        return 1;
    s->now.store(s->resume + (long long)dlnow);
    if (dltotal > 0)
        s->total.store(s->resume + (long long)dltotal);
    return 0;
}

bool curl_to_file(const std::string &url, long asset_id, bool use_auth,
    const std::string &tok, const std::string &out_path, CurlDl *st, bool resume)
{
    long long already = resume ? file_size(out_path) : 0;
    if (!resume)
        already = 0;
    st->resume = already;
    if (st->total.load() < already)
        st->total.store(already);
    st->now.store(already);

    FILE *fp = fopen(out_path.c_str(), already > 0 ? "ab" : "wb");
    if (!fp) {
        std::lock_guard<std::mutex> lock(st->err_mu);
        st->error = "cannot write " + out_path;
        return false;
    }

    CURL *curl = curl_easy_init();
    if (!curl) {
        fclose(fp);
        std::lock_guard<std::mutex> lock(st->err_mu);
        st->error = "curl init failed";
        return false;
    }

    std::string api_url;
    const char *use_url = url.c_str();
    struct curl_slist *hdrs = nullptr;
    if (use_auth && asset_id > 0) {
        std::string repo = read_first_line("/usr/share/zlyme/github-repo");
        api_url = "https://api.github.com/repos/" + repo + "/releases/assets/" +
            std::to_string(asset_id);
        use_url = api_url.c_str();
        hdrs = curl_slist_append(hdrs, "Accept: application/octet-stream");
    }
    if (use_auth && !tok.empty()) {
        std::string auth = "Authorization: Bearer " + tok;
        hdrs = curl_slist_append(hdrs, auth.c_str());
    }

    std::string ca = ca_path();
    curl_easy_setopt(curl, CURLOPT_URL, use_url);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 10L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 15L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 7200L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "zlyme-update");
    curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
    curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, xfer_cb);
    curl_easy_setopt(curl, CURLOPT_XFERINFODATA, st);
    curl_easy_setopt(curl, CURLOPT_RESUME_FROM_LARGE, (curl_off_t)already);
    if (hdrs)
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
    if (!ca.empty())
        curl_easy_setopt(curl, CURLOPT_CAINFO, ca.c_str());
    else {
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }

    CURLcode rc = curl_easy_perform(curl);
    fclose(fp);
    if (hdrs)
        curl_slist_free_all(hdrs);
    curl_easy_cleanup(curl);

    if (st->cancel.load())
        return false;
    if (rc != CURLE_OK) {
        std::lock_guard<std::mutex> lock(st->err_mu);
        st->error = curl_easy_strerror(rc);
        return false;
    }
    return true;
}

void rm_path(const std::string &p)
{
    unlink(p.c_str());
}

bool battery_allows_download()
{
    int bat = PWR_getBattery();
    int charging = PWR_isCharging();
    if (bat > 0 && bat < kMinBatteryPct && !charging) {
        overlay_ok("Battery too low to download.\nPlug in and try again.");
        return false;
    }
    if (bat > 0 && bat < kMinBatteryPct && charging) {
        char buf[96];
        snprintf(buf, sizeof(buf), "Battery is low (%d%%), charging.", bat);
        return wait_ab(buf, "CONTINUE", "BACK");
    }
    return true;
}

void reboot_now()
{
    // Do not PWR_powerOff(): that GFX_quits, writes /tmp/reboot, and
    // exits. nextui-session then restarts NextUI instead of rebooting
    // (the flag is only read when nextui.elf itself exits).
    (void)system("sync");
    if (access("/usr/sbin/zlyme-halt", X_OK) == 0)
        (void)system("/usr/sbin/zlyme-halt reboot");
    else
        (void)system("reboot -f");
    for (;;)
        pause();
}

InputReactionHint do_check(AbstractMenuItem &item)
{
    (void)item;
    if (!PWR_isOnline()) {
        overlay_ok("Wi-Fi is down. Connect first.");
        return NoOp;
    }
    MenuList::showOverlay("Checking for update...", OverlayDismissMode::None);
    g_rel = fetch_meta();
    MenuList::hideOverlay();
    if (!g_rel.ok) {
        overlay_ok(g_rel.error.empty() ? "Check failed" : g_rel.error);
        return NoOp;
    }
    std::string found = std::string("Found ") + short_rel_label();
    if (g_rel.tar_size > 0)
        found += "\n" + fmt_mb(g_rel.tar_size);
    overlay_ok(found);
    return NoOp;
}

InputReactionHint do_notes(AbstractMenuItem &item)
{
    (void)item;
    std::string msg = "OTA is kernel + squashfs.\nGames, BIOS, and Settings stay on ZLYME.\nBackup first from System if you want.\n\n";
    if (!g_rel.ok) {
        msg += "Check for an update first.";
    } else if (trim(g_rel.body).empty()) {
        msg += "No notes in this release.";
    } else {
        std::string body = g_rel.body;
        int lines = 0;
        std::string shown;
        for (size_t i = 0; i < body.size() && lines < 10; i++) {
            shown.push_back(body[i]);
            if (body[i] == '\n')
                lines++;
        }
        if (shown.size() < body.size())
            shown += "\n...";
        msg += shown;
    }
    overlay_ok(msg);
    return NoOp;
}

InputReactionHint do_download(AbstractMenuItem &item)
{
    (void)item;
    if (!PWR_isOnline()) {
        overlay_ok("Wi-Fi is down. Connect first.");
        return NoOp;
    }
    if (!g_rel.ok || g_rel.tar_name.empty()) {
        overlay_ok("Check for an update first.");
        return NoOp;
    }

    if (file_exists(kQueuedTar)) {
        std::string queued = read_first_line(kQueuedName);
        if (queued.empty() || queued == g_rel.tar_name) {
            if (wait_ab("Already queued.", "REBOOT", "LATER"))
                reboot_now();
            return NoOp;
        }
    }

    long long need = g_rel.tar_size + kSlackBytes;
    long long freeb = storage_free();
    if (g_rel.tar_size > 0 && freeb < need) {
        overlay_ok("Not enough space on ZLYME.\nNeed " + fmt_mb(need) + ", free " + fmt_mb(freeb));
        return NoOp;
    }
    if (g_rel.tar_size <= 0 && freeb < 800LL * 1024 * 1024) {
        overlay_ok("Not enough space on ZLYME.");
        return NoOp;
    }
    if (!battery_allows_download())
        return NoOp;

    std::string confirm;
    if (same_running_build()) {
        confirm = "This is the firmware already running.\nDownload ";
        confirm += short_rel_label();
        if (g_rel.tar_size > 0)
            confirm += " (" + fmt_mb(g_rel.tar_size) + ")";
        confirm += " anyway?";
    } else {
        confirm = "Download " + short_rel_label();
        if (g_rel.tar_size > 0)
            confirm += " (" + fmt_mb(g_rel.tar_size) + ")";
        confirm += "?";
    }
    if (!wait_ab(confirm, "DOWNLOAD", "BACK"))
        return NoOp;

    mkdir(kStageDir, 0755);
    clear_failed_slot();
    std::string part = std::string(kStageDir) + "/" + g_rel.tar_name + ".part";
    std::string sha_part = std::string(kStageDir) + "/" + g_rel.sha_name + ".part";
    if (g_rel.sha_name.empty())
        sha_part = std::string(kStageDir) + "/" + g_rel.tar_name + ".sha256.part";

    CurlDl st;
    if (g_rel.tar_size > 0)
        st.total.store(g_rel.tar_size);
    st.t0 = std::chrono::steady_clock::now();
    std::string tok = token_now();
    curl_global_init(CURL_GLOBAL_DEFAULT);

    StayAwake awake;
    std::thread worker([&]() {
        bool ok = curl_to_file(g_rel.tar_url, g_rel.tar_id, g_rel.use_auth, tok, part, &st, true);
        if (!ok && !st.cancel.load() && file_size(part) > 0) {
            {
                std::lock_guard<std::mutex> lock(st.err_mu);
                st.error.clear();
            }
            rm_path(part);
            ok = curl_to_file(g_rel.tar_url, g_rel.tar_id, g_rel.use_auth, tok, part, &st, false);
        }
        if (ok && !st.cancel.load()) {
            CurlDl sha_st;
            sha_st.total.store(4096);
            ok = curl_to_file(g_rel.sha_url, g_rel.sha_id, g_rel.use_auth, tok, sha_part, &sha_st, false);
            if (!ok) {
                std::lock_guard<std::mutex> lock(st.err_mu);
                std::lock_guard<std::mutex> lock2(sha_st.err_mu);
                st.error = sha_st.error.empty() ? std::string("Checksum download failed") : sha_st.error;
            }
        }
        st.done.store(1);
    });

    std::string label = short_rel_label();
    while (!st.done.load()) {
        GFX_startFrame();
        PAD_poll();
        if (PAD_justPressed(BTN_B))
            st.cancel.store(1);
        long long n = st.now.load();
        long long t = st.total.load();
        int pct = (t > 0) ? (int)((n * 100) / t) : 0;
        if (pct > 100)
            pct = 100;
        double frac = (t > 0) ? (double)n / (double)t : 0;
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - st.t0)
                      .count();
        char msg[192];
        if (ms > 1000 && n > 0) {
            double mbs = (n / (1024.0 * 1024.0)) / (ms / 1000.0);
            snprintf(msg, sizeof(msg), "Downloading %s\n%d%%\n%s / %s\n%.1f MB/s",
                label.c_str(), pct, fmt_mb(n).c_str(), fmt_mb(t).c_str(), mbs);
        } else {
            snprintf(msg, sizeof(msg), "Downloading %s\n%d%%\n%s / %s",
                label.c_str(), pct, fmt_mb(n).c_str(), fmt_mb(t).c_str());
        }
        MenuList::showOverlayProgress(msg, frac);
        GFX_sync();
    }
    worker.join();

    if (st.cancel.load()) {
        overlay_ok("Download cancelled.\nPartial file kept for resume.");
        return NoOp;
    }
    std::string err;
    {
        std::lock_guard<std::mutex> lock(st.err_mu);
        err = st.error;
    }
    if (!err.empty()) {
        overlay_ok(std::string("Download failed.\n") + err);
        return NoOp;
    }

    MenuList::showOverlay("Checking hash...", OverlayDismissMode::None);
    std::string want = expected_hash(sha_part);
    std::string got = sha256_of(part);
    if (want.empty() || got.empty() || strcasecmp(want.c_str(), got.c_str()) != 0) {
        rm_path(part);
        rm_path(sha_part);
        overlay_ok("Hash mismatch. File deleted.");
        return NoOp;
    }

    rm_path(kQueuedTar);
    if (rename(part.c_str(), kQueuedTar) != 0) {
        overlay_ok("Could not queue update");
        return NoOp;
    }
    write_file(kQueuedName, g_rel.tar_name);
    rm_path(sha_part);
    (void)system("rm -f /storage/.update/zlyme-my355-*.tar.part "
           "/storage/.update/zlyme-my355-*.sha256.part "
           "/storage/.update/zlyme-my355-*.tar.sha256 "
           "/storage/.update/zlyme-my355-[0-9]*.tar "
           "/storage/.update/zlyme-my355-[0-9]*.sha256 >/dev/null 2>&1");
    (void)system("sync");

    if (wait_ab("Queued. Reboot applies it.", "REBOOT", "LATER"))
        reboot_now();
    else
        overlay_ok("Queued. Reboot when you are ready.");
    return NoOp;
}

} // namespace

MenuList *Zlyme_buildUpdateMenu()
{
    const std::vector<std::any> ch_v = {std::string("releases"), std::string("prereleases")};
    const std::vector<std::string> ch_l = {"Releases", "Prereleases"};

    std::vector<AbstractMenuItem *> items = {
        new MenuItem{ListItemType::Generic, "Channel",
            "Stable tags or workflow builds.",
            ch_v, ch_l,
            []() -> std::any { return channel_now(); },
            [](const std::any &v) {
                ctl_set("update_channel", std::any_cast<std::string>(v).c_str());
                g_rel = ReleaseMeta{};
            },
            []() {
                ctl_set("update_channel", "releases");
                g_rel = ReleaseMeta{};
            }},
        new StaticMenuItem{ListItemType::Generic, "Installed",
            "Current OS.",
            []() -> std::any { return installed_version(); }},
        new StaticMenuItem{ListItemType::Generic, "Available",
            "Latest on this channel.",
            []() -> std::any { return available_label(); }},
        new MenuItem{ListItemType::Button, "Check for update",
            "Needs Wi-Fi.", do_check},
        new MenuItem{ListItemType::Button, "Download and queue",
            "Hash-check, then queue reboot.", do_download},
        new MenuItem{ListItemType::Button, "Notes",
            "Release notes. Games stay.", do_notes},
    };
    return new MenuList(MenuItemType::Fixed, "Update", items);
}

void Zlyme_appendUpdateItem(std::vector<AbstractMenuItem *> &items)
{
    items.push_back(new MenuItem{ListItemType::Generic, "Update",
        "Download an OS update from GitHub.", {}, {}, nullptr, nullptr, DeferToSubmenu,
        Zlyme_buildUpdateMenu()});
}
