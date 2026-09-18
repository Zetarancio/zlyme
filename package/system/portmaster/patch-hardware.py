#!/usr/bin/env python3
"""Map DTB 'Miyoo Flip' so PortMaster does not report CFW/Device unknown."""
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


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch-hardware.py hardware.py", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    text = path.read_text()
    orig = text

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
            print("patch-hardware: missing miyoo pattern", file=sys.stderr)
            return 1
        text = text.replace(needle, needle + "\n" + PATTERN, 1)

    if '"Miyoo Flip"' not in text:
        dneedle = '"Anbernic RG353 M/V/P"'
        idx = text.find(dneedle)
        if idx < 0:
            print("patch-hardware: missing DEVICES rg353m", file=sys.stderr)
            return 1
        line_start = text.rfind("\n", 0, idx) + 1
        text = text[:line_start] + DEVICES + "\n" + text[line_start:]

    if text != orig:
        path.write_text(text)

    # NAME="Zlyme" in os-release; first_run still uses the ROCKNIX/JELOS path.
    plat = path.parent / "platform.py"
    if plat.is_file():
        ptxt = plat.read_text()
        if "'zlyme':" not in ptxt:
            ptxt2 = ptxt.replace(
                "'rocknix':   PlatformROCKNIX,",
                "'rocknix':   PlatformROCKNIX,\n    'zlyme':     PlatformROCKNIX,",
                1,
            )
            if ptxt2 != ptxt:
                plat.write_text(ptxt2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
