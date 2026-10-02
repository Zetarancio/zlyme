#!/usr/bin/env python3
"""Write a private ScreenScraper header. Never prints credential values."""
from __future__ import annotations

import os
import stat
import sys
from pathlib import Path


def load_local(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def pick(name: str, local: dict[str, str]) -> str:
    env = os.environ.get(name)
    if env:
        return env
    return local.get(name, "")


def c_escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: gen-credentials-header.py OUTPUT LOCAL_FILE", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    local = load_local(Path(sys.argv[2]))
    dev_id = pick("SCREENSCRAPER_DEV_ID", local)
    dev_pw = pick("SCREENSCRAPER_DEV_PASSWORD", local)
    if bool(dev_id) != bool(dev_pw):
        print("ScreenScraper developer credentials are incomplete", file=sys.stderr)
        return 1
    required = os.environ.get("ZLYME_REQUIRE_SCRAPEGOAT_CREDENTIALS") == "1"
    if required and not (dev_id and dev_pw):
        print(
            "ScreenScraper developer credentials are required for this build",
            file=sys.stderr,
        )
        return 1
    if dev_id and dev_pw:
        text = (
            f'#define SCREENSCRAPER_DEV_ID "{c_escape(dev_id)}"\n'
            f'#define SCREENSCRAPER_DEV_PASSWORD "{c_escape(dev_pw)}"\n'
        )
    else:
        text = "/* developer credentials were not provided to this build */\n"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    os.chmod(out, stat.S_IRUSR | stat.S_IWUSR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
