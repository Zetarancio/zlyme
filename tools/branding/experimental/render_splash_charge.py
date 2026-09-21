#!/usr/bin/env python3
"""Charging lockup: GIF89a, 90 unique frames, 30 FPS, real alpha.

Does not replace render_charge_loop.py. Output:
  tools/branding/experimental/out/splash/zlyme_charge_loop.gif
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import render_charge_loop as charge
from gif89a import N_FRAMES, SPLASH_OUT, render_loop


def main() -> None:
    charge.N_FRAMES = N_FRAMES
    scene = charge.Charge()
    render_loop(
        scene.composite,
        N_FRAMES,
        SPLASH_OUT / "zlyme_charge_loop.gif",
        "charge-splash",
    )


if __name__ == "__main__":
    main()
