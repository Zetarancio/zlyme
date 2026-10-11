#!/usr/bin/env python3
"""Map DTB 'Miyoo Flip' so PortMaster does not report CFW/Device unknown.

Both files are proven in memory. Neither is replaced unless the Miyoo
Flip identity and the zlyme platform mapping are both present in the
result. A tree that no longer has the ROCKNIX anchor fails closed.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# PortMaster already has HW_INFO for miyoo-flip (RK3566, 640x480, two sticks).
# It did not match DTB model "Miyoo Flip" or list it in DEVICES.
DEVICE = "miyoo-flip"
PATTERN = f"    ('miyoo flip*', '{DEVICE}'),"
DEVICES = (
    '    "Miyoo Flip": '
    f'{{"device": "{DEVICE}", "manufacturer": "Miyoo", "cfw": ["Zlyme", "ROCKNIX"]}},'
)
ROCKNIX_ANCHOR = "'rocknix':   PlatformROCKNIX,"
ZLYME_LINE = "    'zlyme':     PlatformROCKNIX,"
ZLYME_MAP = re.compile(r"'zlyme'\s*:\s*PlatformROCKNIX\b")


def fail(msg: str) -> None:
    print(f"patch-hardware: {msg}", file=sys.stderr)


def flip_ready(text: str) -> bool:
    return (
        "('miyoo flip*', 'miyoo-flip')" in text
        and '"Miyoo Flip"' in text
        and '"device": "miyoo-flip"' in text
        and '"Zlyme"' in text
    )


def patched_hardware(text: str) -> str | None:
    text = text.replace("('miyoo flip*', 'rg353m')", f"('miyoo flip*', '{DEVICE}')")
    text = text.replace(
        '"Miyoo Flip": {"device": "rg353m"',
        f'"Miyoo Flip": {{"device": "{DEVICE}"',
    )
    text = text.replace(
        '"Miyoo Flip": {"device": "miyoo-flip", "manufacturer": "Miyoo", "cfw": ["ROCKNIX"]}',
        '"Miyoo Flip": {"device": "miyoo-flip", "manufacturer": "Miyoo", "cfw": ["Zlyme", "ROCKNIX"]}',
    )

    needle = "('miyoo rk3566 355 v10*', 'miyoo-flip'),"
    if "('miyoo flip*'," not in text:
        if needle not in text:
            fail("missing miyoo pattern")
            return None
        text = text.replace(needle, needle + "\n" + PATTERN, 1)

    if '"Miyoo Flip"' not in text:
        dneedle = '"Anbernic RG353 M/V/P"'
        idx = text.find(dneedle)
        if idx < 0:
            fail("missing DEVICES rg353m")
            return None
        line_start = text.rfind("\n", 0, idx) + 1
        text = text[:line_start] + DEVICES + "\n" + text[line_start:]

    if not flip_ready(text):
        fail("Miyoo Flip identity was not proven")
        return None
    return text


def patched_platform(text: str) -> str | None:
    if ZLYME_MAP.search(text):
        return text
    if ROCKNIX_ANCHOR not in text:
        fail("missing zlyme platform anchor")
        return None
    text = text.replace(
        ROCKNIX_ANCHOR,
        ROCKNIX_ANCHOR + "\n" + ZLYME_LINE,
        1,
    )
    if not ZLYME_MAP.search(text):
        fail("zlyme platform mapping was not proven")
        return None
    return text


def write_if_changed(path: Path, old: str, new: str) -> None:
    if old != new:
        path.write_text(new)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch-hardware.py hardware.py", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    text = path.read_text()
    new_hw = patched_hardware(text)
    if new_hw is None:
        return 1
    plat = path.parent / "platform.py"
    if not plat.is_file():
        fail("platform.py is missing")
        return 1
    old_plat = plat.read_text()
    new_plat = patched_platform(old_plat)
    if new_plat is None:
        return 1
    write_if_changed(path, text, new_hw)
    write_if_changed(plat, old_plat, new_plat)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
