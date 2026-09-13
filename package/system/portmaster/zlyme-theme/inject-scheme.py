#!/usr/bin/env python3
"""Add a Zlyme colour scheme to a PortMaster default_theme theme.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Orange on #050608. No gray fills — those wash out on the light button atlas.
SCHEME = {
    "#pallet": {
        "background": [5, 6, 8, 255],
        "background_fade": [5, 6, 8, 0],
        "list_text": [242, 243, 245, 255],
        "list_selected": [247, 176, 124, 255],
        "list_unselectable": [233, 153, 98, 255],
        "button": [247, 176, 124, 255],
        "general_font": [242, 243, 245],
        "download_font": [5, 6, 8],
        "panels": [5, 6, 8],
        "selection-fill": [247, 176, 124],
        "secondary-selection-fill": [5, 6, 8],
    },
    "#resources": {
        "buttons.png": {"image-mod": [5, 6, 8]},
        "pointenfedde.png": {"image-mod": [247, 176, 124]},
    },
}


def main() -> None:
    path = Path(sys.argv[1])
    data = json.loads(path.read_text())
    info = data.setdefault("#info", {})
    info["name"] = "Zlyme"
    info["creator"] = "Zlyme"
    info["description"] = "Zlyme PortMaster theme. Orange on #050608."
    info["default-scheme"] = "Zlyme"
    schemes = data.setdefault("#schemes", {})
    schemes["Zlyme"] = SCHEME
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
