#!/usr/bin/env python3
"""Fresh-image storage GPT type is Microsoft Basic Data. Layout stays."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CFG = os.path.join(ROOT, "board/my355/genimage.cfg")
BASIC = "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"
LINUX = "0fc63daf-8483-4772-8e79-3d69d8477de4"
GENIMAGE_C = os.path.join(
    ROOT, "output/build/host-genimage-20/image-hd.c"
)


def fail(message):
    print("storage gpt: " + message, file=sys.stderr)
    sys.exit(1)


def shortcuts_from_genimage(path):
    text = open(path, encoding="utf-8").read()
    found = {}
    for name, uuid in re.findall(
        r'\{\s*"([^"]+)"\s*,\s*"([0-9a-fA-F-]{36})"\s*\}', text
    ):
        found.setdefault(name, uuid.lower())
    return found


def resolve(alias, table):
    if alias in table:
        return table[alias]
    if re.fullmatch(r"[0-9a-fA-F-]{36}", alias):
        return alias.lower()
    fail("unknown partition type " + alias)


def blocks(text):
    """Name -> body for partition and image blocks, including nested ones."""
    out = {}
    token = re.compile(r"(image|partition)\s+([\w.]+)\s*\{")
    stack = []
    i = 0
    while i < len(text):
        match = token.match(text, i)
        if match:
            stack.append([match.group(2), match.end(), 1])
            i = match.end()
            continue
        if stack:
            if text[i] == "{":
                stack[-1][2] += 1
            elif text[i] == "}":
                stack[-1][2] -= 1
                if stack[-1][2] == 0:
                    name, start, _depth = stack.pop()
                    out[name] = text[start:i]
        i += 1
    return out


def field(body, key):
    match = re.search(r'^\s*' + re.escape(key) + r'\s*=\s*"?([^"\n]+?)"?\s*$', body, re.M)
    if not match:
        fail("missing " + key)
    return match.group(1).strip()


def main():
    table = {"F": BASIC, "L": LINUX}
    if os.path.isfile(GENIMAGE_C):
        live = shortcuts_from_genimage(GENIMAGE_C)
        for alias, uuid in table.items():
            if live.get(alias) != uuid:
                fail("genimage " + alias + " is " + str(live.get(alias)))
        table = live
    text = open(CFG, encoding="utf-8").read()
    part = blocks(text)
    for name in ("idbloader", "uboot", "boot", "storage", "boot.vfat", "zlyme.img"):
        if name not in part:
            fail("missing block " + name)

    idb = part["idbloader"]
    if "in-partition-table = false" not in idb:
        fail("idbloader is in the partition table")
    if field(idb, "offset") != "32K":
        fail("idbloader offset")
    if field(idb, "image") != "idbloader.img":
        fail("idbloader image")

    uboot = part["uboot"]
    if resolve(field(uboot, "partition-type-uuid"), table) != LINUX:
        fail("uboot type")
    if field(uboot, "offset") != "8M" or field(uboot, "size") != "4M":
        fail("uboot placement")
    if field(uboot, "image") != "u-boot.itb":
        fail("uboot image")

    boot = part["boot"]
    if resolve(field(boot, "partition-type-uuid"), table) != BASIC:
        fail("boot type")
    if field(boot, "offset") != "12M":
        fail("boot offset")
    if "bootable = true" not in boot:
        fail("boot is not bootable")
    if field(boot, "image") != "boot.vfat":
        fail("boot image")

    storage = part["storage"]
    if resolve(field(storage, "partition-type-uuid"), table) != BASIC:
        fail("storage type is not Microsoft Basic Data")
    if field(storage, "image") != "storage.exfat":
        fail("storage image")
    if re.search(r"^\s*(offset|size)\s*=", storage, re.M):
        fail("storage placement changed")

    bootfs = part["boot.vfat"]
    if field(bootfs, "label") != "ZLYMEBOOT":
        fail("boot filesystem label")
    for name in (
        "Image.gz",
        "rk3566-miyoo-flip.dtb",
        "extlinux",
        "overlays",
        "zlyme-boot.conf",
        "zlyme",
        "splash.anim",
        "progress.anim",
        "miyoo355_fw.img",
    ):
        if '"' + name + '"' not in bootfs:
            fail("boot file missing: " + name)

    device = open(
        os.path.join(ROOT, "board/my355/fsoverlay/usr/share/zlyme/device.conf"),
        encoding="utf-8",
    ).read()
    if "ZLYME_STORAGE_LABEL=ZLYME\n" not in device:
        fail("storage filesystem label")
    print("storage gpt ok")


if __name__ == "__main__":
    main()
