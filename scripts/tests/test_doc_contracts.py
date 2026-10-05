#!/usr/bin/env python3
"""Exact values that canonical docs restate from one source line."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import zlyme_release  # noqa: E402

CANONICAL = (
    "AGENTS.md",
    "README.md",
    "docs/USER_GUIDE.md",
    "docs/ARCHITECTURE.md",
    "docs/DEVICE_PORTING.md",
    "docs/DEVELOPMENT.md",
    "docs/OPERATIONS.md",
    "docs/UPSTREAMS.md",
    "docs/MAINTENANCE.md",
    "docs/ENGINEERING_PRINCIPLES.md",
)
PRODUCT = "configs/zlyme_my355_defconfig"
# The stale canonical sentence that an earlier, format-bound check missed.
STALE_RUMBLE = (
    "- Settings owns calibration, deadzone, and displayed Rumble Strength. "
    "The product default is displayed 30%, mapped to `FF_GAIN` by the "
    "userspace curve."
)


def rumble_defaults(text):
    """Percentages stated as the default or fresh-install Rumble Strength."""
    found = []
    for line in text.splitlines():
        if "rumble" not in line.lower():
            continue
        found += re.findall(r"(?:default|fresh install)\D{0,60}?(\d+)\s?%", line, re.I)
    return found
MINIMAL = "configs/zlyme_my355_minimal_defconfig"


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as handle:
        return handle.read()


def source(rel, pattern):
    match = re.search(pattern, read(rel), re.M)
    if not match:
        sys.exit("%s: no match for %s" % (rel, pattern))
    return match.group(1)


def main():
    bad = []

    version = read("ZLYME_VERSION").strip()
    try:
        zlyme_release.parse_version(version)
    except zlyme_release.ReleaseError:
        bad.append("ZLYME_VERSION %r is not zlymeNN or zlymeNN.M" % version)

    keys = {
        "Linux": r'^BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="([^"]+)"',
        "U-Boot": r'^BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE="([^"]+)"',
        "BL31": r'^BR2_PACKAGE_ROCKCHIP_RKBIN_BL31_FILENAME="bin/rk35/([^"]+)\.elf"',
        "TPL": r'^BR2_PACKAGE_ROCKCHIP_RKBIN_TPL_FILENAME="bin/rk35/([^"]+)\.bin"',
    }
    pins = {"Buildroot": source("build.sh", r'^readonly BUILDROOT_VERSION="([^"]+)"')}
    for name, pattern in keys.items():
        pins[name] = source(PRODUCT, pattern)
        if source(MINIMAL, pattern) != pins[name]:
            bad.append("%s differs between the two defconfigs" % name)

    mentions = {
        "Buildroot": r"Buildroot `?(\d{4}\.\d{2}(?:\.\d+)?)",
        "Linux": r"\bLinux `?(\d+\.\d+\.\d+)",
        "U-Boot": r"U-Boot `?(\d{4}\.\d{2})",
        "BL31": r"(rk3568_bl31_v[\d.]*\d)",
        "TPL": r"(rk3566_ddr_\d+MHz_v[\d.]*\d)",
    }
    for rel in CANONICAL:
        text = read(rel)
        for name, pattern in mentions.items():
            for found in re.findall(pattern, text):
                if found != pins[name]:
                    bad.append("%s names %s %s, source has %s" % (rel, name, found, pins[name]))

    dev = read("docs/DEVELOPMENT.md")
    for name in ("Buildroot", "Linux", "U-Boot"):
        row = re.search(r"^\| %s \| `([^`]+)`" % re.escape(name), dev, re.M)
        if not row or row.group(1) != pins[name]:
            bad.append("docs/DEVELOPMENT.md pinned baseline row %s" % name)

    nextui = source("package/system/nextui/nextui.mk", r"^NEXTUI_VERSION = ([0-9a-f]{40})$")
    row = re.search(r"^\| NextUI fork \|[^\n]*`([0-9a-f]{40})`", read("docs/UPSTREAMS.md"), re.M)
    if not row or row.group(1) != nextui:
        bad.append("docs/UPSTREAMS.md NextUI fork row is not NEXTUI_VERSION")

    conf = "board/my355/fsoverlay/usr/share/zlyme/device.conf"
    want = sorted(
        line.strip()
        for line in read(conf).splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )
    for rel in ("docs/ARCHITECTURE.md", "docs/DEVICE_PORTING.md"):
        block = re.search(r"```sh\n(ZLYME_DEVICE_ID=.*?)```", read(rel), re.S)
        got = sorted(line.strip() for line in block.group(1).splitlines() if line.strip()) if block else []
        if got != want:
            bad.append("%s device.conf block differs from %s" % (rel, conf))

    gain = source(
        "package/system/nextui/zlyme/gamepad-ff/ff_gain.h",
        r"^#define FF_DEFAULT_GAIN_PERCENT (\d+)$",
    )
    if rumble_defaults(STALE_RUMBLE) != ["30"]:
        bad.append("rumble check no longer sees the stale 30% sentence")
    for rel in CANONICAL:
        stated = rumble_defaults(read(rel))
        if rel in ("docs/ARCHITECTURE.md", "docs/USER_GUIDE.md") and not stated:
            bad.append("%s no longer states the Rumble Strength default" % rel)
        for found in stated:
            if found != gain:
                bad.append("%s says the Rumble Strength default is %s%%, FF_DEFAULT_GAIN_PERCENT is %s"
                           % (rel, found, gain))

    # The Zlyme Installer links to github.com/Zetarancio/zlyme#install.
    if not re.search(r"^## Install$", read("README.md"), re.M):
        bad.append("README.md has no '## Install' heading for the installer's #install link")

    if bad:
        print("\n".join(bad), file=sys.stderr)
        return 1
    print("doc contracts ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
