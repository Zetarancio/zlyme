#!/bin/sh
# Settings placement, recovery power choice, and hint ownership.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
UI=${1:-$ROOT/../zlyme-nextui/workspace/all/settings}
python3 - "$UI" << 'PY'
import pathlib, sys
ui = pathlib.Path(sys.argv[1])

def read(name):
    return (ui / name).read_text()

def body(text, start, end):
    a = text.find(start)
    b = text.find(end, a + len(start))
    if a < 0 or b < 0:
        raise SystemExit(f"missing span {start!r} .. {end!r}")
    return text[a:b]

menu = read("zlymemenu.cpp")
settings = read("settings.cpp")
hints = read("menu.hpp")
start = menu.find("void Zlyme_appendGameCleanup")
if start < 0:
    raise SystemExit("Game cleanup function is missing")
game = menu[start:]
system = body(menu, "void Zlyme_appendSystemItems", "void Zlyme_appendBackupItem")
if "Reset PortMaster" not in game:
    raise SystemExit("Reset PortMaster is not on the Game cleanup list")
if "Reset PortMaster" in system:
    raise SystemExit("Reset PortMaster is still under System")
if "Reset Settings" not in system or "Factory Reset" not in system:
    raise SystemExit("system resets moved")
if 'zlyme-reset portmaster' in menu or 'zlyme-reset "portmaster"' in menu:
    pass
if 'std::string("zlyme-reset ")' not in menu:
    raise SystemExit("reset helper is gone")

arm = body(menu, "static InputReactionHint recovery_arm_now", "static InputReactionHint recovery_disarm_now")
disarm = body(menu, "static InputReactionHint recovery_disarm_now", "static MenuList *recovery_final")
restore = body(menu, "static InputReactionHint recovery_restore_now", "static std::string recovery_brief")
for name, fn in (("arm", arm), ("disarm", disarm), ("restore", restore)):
    if "recovery_offer_power" not in fn:
        raise SystemExit(f"{name} success does not offer power")
    if "code == 0" not in fn:
        raise SystemExit(f"{name} has no success branch")
    ok, _, fail = fn.partition("code == 0")
    fail = fail.split("return NoOp;", 1)[-1]
    if "showOverlay" not in fail:
        raise SystemExit(f"{name} failure does not stay on a diagnostic overlay")
    if "recovery_offer_power" in fail:
        raise SystemExit(f"{name} failure also offers power")
if "prepare-recovery" not in arm or "arm-recovery" not in arm:
    raise SystemExit("arm no longer prepares then arms")
if arm.find("prepare-recovery") > arm.find("arm-recovery"):
    raise SystemExit("arm runs before prepare")
if "showOverlay" not in arm.split("arm-recovery", 1)[0]:
    raise SystemExit("prepare failure does not show a diagnostic")
if "Recovery is armed." not in arm or "right-hand bootable card" not in arm:
    raise SystemExit("arm success text dropped the cold-boot MASKROM steps")
if "Restart only performs a normal reboot." not in arm:
    raise SystemExit("arm success does not say restart is a normal reboot")
for banned in ("Restart to enter MASKROM", "Reboot into MASKROM", "Reboot to MASKROM"):
    if banned in menu:
        raise SystemExit(f"banned MASKROM wording: {banned}")
if "poweroff -f" in menu or "reboot -f" in menu:
    raise SystemExit("Settings invokes a raw power command")
if 'fopen("/tmp/poweroff"' not in menu or 'fopen("/tmp/reboot"' not in menu:
    raise SystemExit("session power markers are missing")
prompt = body(menu, "void Zlyme_promptRebootOnExit", "static int cleanup_count")
if '"/tmp/reboot"' not in prompt or '"/tmp/poweroff"' not in prompt:
    raise SystemExit("pending restart prompt ignores a power marker")
if "Shut down" not in menu or "Restart" not in menu:
    raise SystemExit("power chooser rows are missing")

if "virtual bool ownsHints() const { return false; }" not in hints:
    raise SystemExit("MenuList does not default to standard hints")
if "activeMenu" not in hints:
    raise SystemExit("hint ownership does not follow the active menu")
if "appManagesHints = true" not in settings:
    raise SystemExit("Settings does not reserve standard hints")
if "ownsHints()" not in settings:
    raise SystemExit("Settings always paints generic hints")
if '== "Recovery"' in settings or '== "Joysticks"' in settings:
    raise SystemExit("hint policy matches page titles")
for name in ("colorpickermenu.hpp", "keyboardprompt.hpp", "zlymeupdate.cpp"):
    text = read(name)
    if "ownsHints() const override { return true; }" not in text:
        raise SystemExit(f"{name} does not own its hints")
joy = read("zlymejoystick.cpp")
if 'MenuItemType::Fixed, "Joysticks"' not in joy:
    raise SystemExit("Joysticks main page is not a normal list")
if "ownsHints" in joy:
    raise SystemExit("joystick screens opted out of the main-list hints")
if 'hint_left("B", "BACK")' not in joy:
    raise SystemExit("joystick screens lost their Back hint")
rec = body(menu, "std::vector<AbstractMenuItem *> recovery;", "advanced.push_back")
if 'MenuItemType::Fixed, "Recovery"' not in system:
    raise SystemExit("Recovery main page is not a normal list")
if "Preloader status" not in rec:
    raise SystemExit("preloader status row is gone")
print("settings ux ok")
PY
