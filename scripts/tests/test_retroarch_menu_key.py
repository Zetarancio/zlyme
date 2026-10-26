#!/usr/bin/env python3
"""Prove RetroArch 1.22.2 registers menu_swap_ok_cancel_buttons."""
import os
import re
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MK = os.path.join(ROOT, "package/emulators/retroarch/retroarch.mk")
version = None
with open(MK, encoding="utf-8") as fh:
    for line in fh:
        if line.startswith("RETROARCH_VERSION = "):
            version = line.split("=", 1)[1].strip()
            break
if version != "v1.22.2":
    sys.exit(f"retroarch pin is {version}, expected v1.22.2")

src = os.environ.get("ZLYME_RETROARCH_SRC", "")
files = {
    "configuration.c": "configuration.c",
    "config.def.h": "config.def.h",
    "menu/menu_driver.c": "menu_driver.c",
}


def load(rel):
    if src:
        path = os.path.join(src, rel)
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    url = (
        "https://raw.githubusercontent.com/libretro/RetroArch/"
        + version
        + "/"
        + rel
    )
    with urllib.request.urlopen(url, timeout=30) as resp:
        return resp.read().decode("utf-8")


config = load("configuration.c")
defs = load("config.def.h")
menu = load("menu/menu_driver.c")

registered = set(re.findall(r'SETTING_BOOL\(\s*"([^"]+)"', config))
if "menu_swap_ok_cancel_buttons" not in registered:
    sys.exit("menu_swap_ok_cancel_buttons is not a registered setting")
if "input_menu_swap_ok_cancel_buttons" in registered:
    sys.exit("input_menu_swap_ok_cancel_buttons is a registered file key")

if not re.search(
    r"#define\s+DEFAULT_MENU_SWAP_OK_CANCEL_BUTTONS\s+true\b", defs
):
    sys.exit("upstream default is not true")

ok = re.search(
    r"unsigned menu_ok_btn\s*=\s*swap_ok_cancel_btns\s*\?\s*"
    r"RETRO_DEVICE_ID_JOYPAD_B\s*:\s*RETRO_DEVICE_ID_JOYPAD_A\s*;",
    menu,
)
cancel = re.search(
    r"unsigned menu_cancel_btn\s*=\s*swap_ok_cancel_btns\s*\?\s*"
    r"RETRO_DEVICE_ID_JOYPAD_A\s*:\s*RETRO_DEVICE_ID_JOYPAD_B\s*;",
    menu,
)
if not ok or not cancel:
    sys.exit("menu driver does not select B for OK when the setting is true")

stock = os.path.join(
    ROOT, "board/my355/fsoverlay/usr/share/zlyme/retroarch/retroarch.cfg"
)
text = open(stock, encoding="utf-8").read()
if 'menu_swap_ok_cancel_buttons = "false"' not in text:
    sys.exit("stock file does not set the registered key false")
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("#"):
        continue
    if stripped.startswith("input_menu_swap_ok_cancel_buttons"):
        sys.exit("stock file still sets the unregistered key")
print("retroarch menu key ok")
