#!/usr/bin/env python3
"""Prove PPSSPP v1.19.3 loads controls.ini, not ppsspp.ini, for buttons."""
import os
import re
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MK = os.path.join(ROOT, "package/emulators/ppsspp/ppsspp.mk")
version = None
with open(MK, encoding="utf-8") as fh:
    for line in fh:
        if line.startswith("PPSSPP_VERSION = "):
            version = line.split("=", 1)[1].strip()
            break
if version != "v1.19.3":
    sys.exit(f"ppsspp pin is {version}, expected v1.19.3")


def load(rel):
    url = (
        "https://raw.githubusercontent.com/hrydgard/ppsspp/"
        + version
        + "/"
        + rel
    )
    with urllib.request.urlopen(url, timeout=30) as resp:
        return resp.read().decode("utf-8")


config = load("Core/Config.cpp")
keymap = load("Core/KeyMap.cpp")
sdl = load("SDL/SDLJoystick.cpp")
if 'controls.ini' not in config or "LoadStandardControllerIni" not in config:
    sys.exit("controller settings are not loaded from controls.ini")
if "KeyMap::LoadFromIni" not in config:
    sys.exit("the controller ini is not passed to KeyMap")
if 'file.HasSection("ControlMapping")' not in keymap:
    sys.exit("LoadFromIni does not read ControlMapping")
if "PSP_SYSTEMPARAM_BUTTON_CROSS ? CTRL_CROSS : CTRL_CIRCLE" not in keymap:
    sys.exit("menu confirm does not follow the Cross preference")
if not re.search(
    r"ConfigSetting\(\"ButtonPreference\".*PSP_SYSTEMPARAM_BUTTON_CROSS",
    config,
):
    sys.exit("ButtonPreference does not default to Cross")
pairs = {
    "SDL_CONTROLLER_BUTTON_A": "NKCODE_BUTTON_2",
    "SDL_CONTROLLER_BUTTON_B": "NKCODE_BUTTON_3",
    "SDL_CONTROLLER_BUTTON_X": "NKCODE_BUTTON_4",
    "SDL_CONTROLLER_BUTTON_Y": "NKCODE_BUTTON_1",
}
for button, code in pairs.items():
    if not re.search(rf"case {button}:\s*return {code};", sdl):
        sys.exit(f"{button} does not return {code}")
print("ppsspp controls.ini contract ok")
