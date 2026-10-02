#!/usr/bin/env python3
"""Fresh PortMaster config uses default_theme / Zlyme.

A stored theme named Zlyme is the removed standalone theme. Convert that
one case. Any other theme or scheme is left alone. The obsolete
themes/Zlyme directory is removed when it is present.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path


class MalformedConfig(Exception):
    pass


def load_config(path: Path) -> dict:
    if not path.is_file():
        return {}
    text = path.read_text()
    if not text.strip():
        raise MalformedConfig()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise MalformedConfig() from exc
    if not isinstance(data, dict):
        raise MalformedConfig()
    return data


def migrate(data: dict) -> bool:
    theme = data.get("theme")
    scheme = data.get("theme-scheme")
    if theme == "Zlyme":
        data["theme"] = "default_theme"
        data["theme-scheme"] = "Zlyme"
        return True
    if theme in (None, "") and scheme in (None, ""):
        data["theme"] = "default_theme"
        data["theme-scheme"] = "Zlyme"
        return True
    return False


def remove_obsolete_theme(themes_dir: Path) -> None:
    obsolete = themes_dir / "Zlyme"
    if obsolete.is_dir():
        shutil.rmtree(obsolete)


def main() -> None:
    cfg = Path(sys.argv[1])
    themes = Path(sys.argv[2])
    remove_obsolete_theme(themes)
    try:
        data = load_config(cfg)
    except MalformedConfig:
        print(
            "portmaster: config.json is not valid JSON; leaving it unchanged",
            file=sys.stderr,
        )
        return
    if not migrate(data):
        return
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(json.dumps(data, indent=4) + "\n")


if __name__ == "__main__":
    main()
