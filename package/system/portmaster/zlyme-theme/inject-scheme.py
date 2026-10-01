#!/usr/bin/env python3
"""Add the Zlyme colour scheme to PortMaster's default_theme.

The scheme is a copy of upstream Darkest Mode. Layout, scenes, resources,
and every colour that is not a red or blue selection accent stay as they
are. Three palette values change:

- list_unselectable was Darkest Mode red (200, 0, 0). It becomes
  #FA7C08, COLORS.md color1.
- list_selected was the light blue (153, 180, 255). It becomes #FFD7B0.
  COLORS.md has no pastel, so this is #FC9C14 (the lighter brand orange)
  mixed toward white.
- selection-fill was the dark blue (50, 80, 155). It becomes #8A3E06,
  #FA7C08 mixed with the #050608 background, so the pastel text stays
  readable on the selection bar.
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

ZLYME_ORANGE = [250, 124, 8]  # #FA7C08
PASTEL_ORANGE = [255, 215, 176]  # #FFD7B0
SELECTION_FILL = [138, 62, 6]  # #8A3E06


def apply_scheme(data: dict) -> dict:
    schemes = data.setdefault("#schemes", {})
    darkest = schemes.get("Darkest Mode")
    if not isinstance(darkest, dict):
        raise SystemExit("default_theme has no Darkest Mode scheme")
    scheme = copy.deepcopy(darkest)
    pallet = scheme.setdefault("#pallet", {})
    unselectable = list(pallet.get("list_unselectable", []))
    selected = list(pallet.get("list_selected", []))
    fill = list(pallet.get("selection-fill", []))
    if len(unselectable) < 3 or len(selected) < 3 or len(fill) < 3:
        raise SystemExit("Darkest Mode palette is missing a selection colour")
    pallet["list_unselectable"] = ZLYME_ORANGE + unselectable[3:]
    pallet["list_selected"] = PASTEL_ORANGE + selected[3:]
    pallet["selection-fill"] = SELECTION_FILL + fill[3:]
    schemes["Zlyme"] = scheme
    info = data.setdefault("#info", {})
    info["default-scheme"] = "Zlyme"
    return data


def main() -> None:
    path = Path(sys.argv[1])
    data = json.loads(path.read_text())
    apply_scheme(data)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
