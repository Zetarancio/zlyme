#!/usr/bin/env python3
"""Boot splash slime: GIF89a, 135 unique frames, 4.5 s at 30 FPS, real alpha.

Does not replace render_slime_loop.py (APNG preview). Output:
  tools/branding/experimental/out/splash/zlyme_slime_loop.gif
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import render_slime_loop as slime
from gif89a import SPLASH_OUT, render_loop

# 4.5 s × 30 FPS. Delay is still 33 ms (GIF stores 3 cs = 30 ms).
N_SLIME = 135


def main() -> None:
    slime.N_FRAMES = N_SLIME
    scene = slime.Scene()
    render_loop(
        scene.composite,
        N_SLIME,
        SPLASH_OUT / "zlyme_slime_loop.gif",
        "slime-splash",
    )


if __name__ == "__main__":
    main()
