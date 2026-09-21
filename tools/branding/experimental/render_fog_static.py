#!/usr/bin/env python3
"""Smoked-glass lockup still (PNG). Empty glass + magician-ball wisps."""
from __future__ import annotations

from glass import FOG_PNG, write_glass_fog


def main() -> None:
    write_glass_fog(FOG_PNG)


if __name__ == "__main__":
    main()
