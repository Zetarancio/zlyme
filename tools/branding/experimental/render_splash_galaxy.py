#!/usr/bin/env python3
"""Resize/OTA splash galaxy: GIF89a, 90 unique frames, 30 FPS, real alpha.

Composites refs/zlyme_galaxy_3d_rotation_3s_200px_30fps.gif behind empty
glass. Does not replace render_galaxy_loop.py. Output:
  tools/branding/experimental/out/splash/zlyme_galaxy_loop.gif
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import numpy as np

import render_galaxy_loop as galaxy
from gif89a import N_FRAMES, SPLASH_OUT, render_loop


def main() -> None:
    scene = galaxy.Galaxy()
    dest = SPLASH_OUT / "zlyme_galaxy_loop.gif"
    render_loop(scene.composite, N_FRAMES, dest, "galaxy-splash")
    wrap = scene.composite(1.0)
    first = scene.composite(0.0)
    d = np.abs(first.astype(np.int16) - wrap.astype(np.int16))
    print(f"loop seam max|Δ|={int(d.max())} mean|Δ|={float(d.mean()):.4f}")


if __name__ == "__main__":
    main()
